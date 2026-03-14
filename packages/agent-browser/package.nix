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
  version = "0.20.0";

  src = fetchFromGitHub {
    owner = "vercel-labs";
    repo = "agent-browser";
    rev = "v${version}";
    hash = "sha256-04Y3OUiCfuIimO0KmF7VPFG3REvqD+nq7QprnuIZwKE=";
  };

  sourceRoot = "source/cli";

  cargoHash = "sha256-7l/2Q1P5JIC+kp0Pm729LBXXHVDt//Xe1cieWHjcvdc=";

  nativeBuildInputs = lib.optional stdenv.isLinux makeBinaryWrapper;
  buildInputs = lib.optional stdenv.isLinux chromium;

  # Auth/credential tests require a keyring unavailable in the sandbox
  doCheck = false;

  postInstall = lib.optionalString stdenv.isLinux ''
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
