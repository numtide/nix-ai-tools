{
  lib,
  fetchFromGitHub,
  chromium,
  makeBinaryWrapper,
  rustPlatform,
  stdenv,
}:

rustPlatform.buildRustPackage rec {
  pname = "agent-browser";
  version = "0.23.0";

  src = fetchFromGitHub {
    owner = "vercel-labs";
    repo = "agent-browser";
    rev = "v${version}";
    hash = "sha256-ZUcPPsLueMPEiCVXE9N4oBf5xwYvxQ71jfkbo9t/8xs=";
  };

  sourceRoot = "source/cli";

  cargoHash = "sha256-Ha+R/tlSYfCb/POuoOauQqYXxmY7Dypn/wp1WwZPQ4w=";

  nativeBuildInputs = lib.optional stdenv.hostPlatform.isLinux makeBinaryWrapper;
  buildInputs = lib.optional stdenv.hostPlatform.isLinux chromium;

  # Upstream enables fat LTO with codegen-units=1 while pulling in the full
  # `image` crate (avif/webp/tiff/jpeg/png/gif codecs). The final monolithic
  # LTO link OOMs rustc on the aarch64-linux builder. Thin LTO keeps most of
  # the optimisation at a fraction of the peak memory.
  env.CARGO_PROFILE_RELEASE_LTO = "thin";

  # Auth/credential tests require a keyring unavailable in the sandbox
  doCheck = false;

  postInstall = lib.optionalString stdenv.hostPlatform.isLinux ''
    wrapProgram $out/bin/agent-browser \
      --set AGENT_BROWSER_EXECUTABLE_PATH ${chromium}/bin/chromium
  '';

  passthru.category = "Utilities";

  meta = {
    description = "Headless browser automation CLI for AI agents";
    homepage = "https://github.com/vercel-labs/agent-browser";
    changelog = "https://github.com/vercel-labs/agent-browser/releases/tag/v${version}";
    license = lib.licenses.asl20;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    platforms = lib.platforms.all;
    mainProgram = "agent-browser";
  };
}
