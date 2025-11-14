{
  lib,
  stdenv,
  fetchFromGitHub,
  installShellFiles,
  rustPlatform,
  pkg-config,
  openssl,
  versionCheckHook,
  installShellCompletions ? stdenv.buildPlatform.canExecute stdenv.hostPlatform,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "codex";
  version = "0.58.0";

  src = fetchFromGitHub {
    owner = "openai";
    repo = "codex";
    tag = "rust-v${finalAttrs.version}";
    hash = "sha256-CY9ai6Ia6bixACEIIWc85DqFDUf31zMnVJTqkVQArDs=";
  };

  sourceRoot = "${finalAttrs.src.name}/codex-rs";

  cargoHash = "sha256-FqGgHzq9JhegpRQEpOGtTmdnfypOeIlE43SdWs1/ddM=";

  cargoBuildFlags = [
    "--package"
    "codex-cli"
  ];

  nativeBuildInputs = [
    installShellFiles
    pkg-config
  ];

  buildInputs = [ openssl ];

  preBuild = ''
    # Remove LTO to speed up builds
    substituteInPlace Cargo.toml \
      --replace-fail 'lto = "fat"' 'lto = false'
  '';

  doCheck = false;

  postInstall = lib.optionalString installShellCompletions ''
    installShellCompletion --cmd codex \
      --bash <($out/bin/codex completion bash) \
      --fish <($out/bin/codex completion fish) \
      --zsh <($out/bin/codex completion zsh)
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  passthru = {
    updateScript = ./update.sh;
  };

  meta = {
    description = "OpenAI Codex CLI - a coding agent that runs locally on your computer";
    homepage = "https://github.com/openai/codex";
    changelog = "https://github.com/openai/codex/releases/tag/rust-v${finalAttrs.version}";
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    license = lib.licenses.asl20;
    mainProgram = "codex";
    platforms = lib.platforms.unix;
  };
})
