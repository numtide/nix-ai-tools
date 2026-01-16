{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchPnpmDeps,
  cmake,
  git,
  makeWrapper,
  nodejs-slim,
  pnpm,
  pnpmConfigHook,
  versionCheckHook,
  versionCheckHomeHook,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "clawdbot";
  version = "2026.1.14-1";

  src = fetchFromGitHub {
    owner = "clawdbot";
    repo = "clawdbot";
    rev = "v${finalAttrs.version}";
    hash = "sha256-UuzOkJUbmgcjj6ba+uIhmZdDMNs9NRyyTPEEf+3cFSg=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    hash = "sha256-hqujaLScFYdVnN4D8x35cKgCLqG2f9WTPFNC2ikBd7o=";
    fetcherVersion = 2;
  };

  nativeBuildInputs = [
    cmake
    git
    makeWrapper
    nodejs-slim
    pnpm
    pnpmConfigHook
  ];

  # Prevent cmake from automatically running in configure phase
  # (it's only needed for npm postinstall scripts)
  dontUseCmakeConfigure = true;

  buildPhase = ''
    runHook preBuild

    pnpm build

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/{bin,lib/clawdbot}
    
    # Copy required runtime directories
    cp -r dist $out/lib/clawdbot/
    cp -r node_modules $out/lib/clawdbot/
    cp -r extensions $out/lib/clawdbot/
    cp -r skills $out/lib/clawdbot/
    cp -r patches $out/lib/clawdbot/
    cp -r ui $out/lib/clawdbot/
    
    # Copy additional directories from package.json "files" field
    cp -r assets $out/lib/clawdbot/
    cp -r docs $out/lib/clawdbot/
    
    # Copy package metadata
    cp package.json $out/lib/clawdbot/

    makeWrapper ${nodejs-slim}/bin/node $out/bin/clawdbot \
      --add-flags "$out/lib/clawdbot/dist/entry.js"

    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];

  passthru.category = "Utilities";

  meta = {
    description = "Personal AI assistant with WhatsApp, Telegram, Discord integration";
    homepage = "https://clawd.bot";
    changelog = "https://github.com/clawdbot/clawdbot/releases";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with lib.maintainers; [ ];
    platforms = lib.platforms.all;
    mainProgram = "clawdbot";
  };
})
