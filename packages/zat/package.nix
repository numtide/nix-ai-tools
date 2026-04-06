{
  lib,
  flake,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "zat";
  version = "0.5.3";

  src = fetchFromGitHub {
    owner = "bglgwyng";
    repo = "zat";
    tag = "v${finalAttrs.version}";
    hash = "sha256-B/DT8hdtOds9d/od5QInuRu5rBprxzJOfbuj3LkGCvk=";
  };

  cargoHash = "sha256-VSu68KPkoOLyva+A3+TtdTg48xZg0LNenMq+z9xoAVU=";

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
    license = lib.licenses.gpl3Only;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ mic92 ];
    mainProgram = "zat";
    platforms = lib.platforms.unix;
  };
})
