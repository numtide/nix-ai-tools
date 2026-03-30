{
  lib,
  flake,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "zat";
  version = "0.5.1";

  src = fetchFromGitHub {
    owner = "bglgwyng";
    repo = "zat";
    tag = "v${finalAttrs.version}";
    hash = "sha256-SP+ezyWHpC/MPlJu2ZJbPt2ZkI523/u7O0HxFK0C91U=";
  };

  cargoHash = "sha256-7O6zFovE7argbYVE5R+tlco/Kn78haE19vIiR1D8fEU=";

  # Smoke test: zat has no --version flag, so run it against its own source.
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    $out/bin/zat src/main.rs > /dev/null
    runHook postInstallCheck
  '';

  passthru.category = "Utilities";

  meta = {
    description = "Code outline viewer for LLM coding agents — shows exported symbols with line numbers";
    homepage = "https://github.com/bglgwyng/zat";
    changelog = "https://github.com/bglgwyng/zat/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ mic92 ];
    mainProgram = "zat";
    platforms = lib.platforms.unix;
  };
})
