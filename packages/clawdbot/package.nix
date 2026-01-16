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
  version = "2026.1.15";

  src = fetchFromGitHub {
    owner = "clawdbot";
    repo = "clawdbot";
    rev = "v${finalAttrs.version}";
    hash = "sha256-QN9ffRChZqU4yde9aaRJu2yJEBmu3hJk20tlMkvhNag=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    hash = "sha256-VfOoHBhpDZxs5dugyOGpBWaqlc4nMqpuJgb2XtvtcFM=";
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

    cp -r * $out/lib/clawdbot/

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
