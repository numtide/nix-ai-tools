{
  lib,
  flake,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "zat";
  version = "0.5.2";

  src = fetchFromGitHub {
    owner = "bglgwyng";
    repo = "zat";
    tag = "v${finalAttrs.version}";
    hash = "sha256-DaFFg7Aj03mUU9wYnwx+6EfOOkQ1t8QSVBGYZoj3i+8=";
  };

  cargoHash = "sha256-IRzYQh9VOQtkPmmvvAWjrDJIdoKrbK6YuVk/auI5Gns=";

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
