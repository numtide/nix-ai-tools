{
  lib,
  fetchFromGitHub,
  fetchPnpmDeps,
  chromium,
  makeBinaryWrapper,
  nodejs-slim,
  pnpmConfigHook,
  pnpm_10,
  rustPlatform,
  stdenv,
}:

let
  pname = "agent-browser";
  version = "0.25.3";

  src = fetchFromGitHub {
    owner = "vercel-labs";
    repo = "agent-browser";
    rev = "v${version}";
    hash = "sha256-9wunuGSsxKqy9h3MMahW3hzZ+5iJrz/SotPRRGDu+kg=";
  };

  dashboard = stdenv.mkDerivation {
    pname = "${pname}-dashboard";
    inherit version src;

    nativeBuildInputs = [
      nodejs-slim
      pnpm_10
      pnpmConfigHook
    ];

    pnpmDeps = fetchPnpmDeps {
      pname = "${pname}-dashboard";
      inherit version src;
      pnpm = pnpm_10;
      hash = "sha256-p9xpkR15JRq3zzx0GtICpETqRWLyHT7RTgkQ0Y9qWsY=";
      fetcherVersion = 2;
    };

    buildPhase = ''
      runHook preBuild
      cd packages/dashboard
      pnpm build
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r out/. $out/
      runHook postInstall
    '';
  };
in
rustPlatform.buildRustPackage {
  inherit pname version src;

  sourceRoot = "source/cli";

  cargoHash = "sha256-vCxv2vKSWj5kIWhzWlbWNfEHrxnSg1i0nUBq6hWoQlM=";

  nativeBuildInputs = lib.optional stdenv.hostPlatform.isLinux makeBinaryWrapper;
  buildInputs = lib.optional stdenv.hostPlatform.isLinux chromium;

  # Upstream enables fat LTO with codegen-units=1 while pulling in the full
  # `image` crate (avif/webp/tiff/jpeg/png/gif codecs). The final monolithic
  # LTO link OOMs rustc on the aarch64-linux builder. Thin LTO keeps most of
  # the optimisation at a fraction of the peak memory.
  env.CARGO_PROFILE_RELEASE_LTO = "thin";

  # cargo-auditable panics on aarch64-darwin with this crate's dependency tree
  auditable = !stdenv.hostPlatform.isDarwin;

  # Auth/credential tests require a keyring unavailable in the sandbox
  doCheck = false;

  postPatch = ''
    substituteInPlace build.rs \
      --replace-fail 'Path::new("../packages/dashboard/out")' 'Path::new("${dashboard}")'
    substituteInPlace src/native/stream/http.rs \
      --replace-fail '#[folder = "../packages/dashboard/out/"]' '#[folder = "${dashboard}/"]'
  '';

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
