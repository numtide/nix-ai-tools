{
  lib,
  stdenv,
  fetchFromGitHub,
  installShellFiles,
  rustPlatform,
  pkg-config,
  openssl,
  installShellCompletions ? stdenv.buildPlatform.canExecute stdenv.hostPlatform,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "code";
  version = "0.2.169";

  src = fetchFromGitHub {
    owner = "just-every";
    repo = "code";
    tag = "v${finalAttrs.version}";
    hash = "sha256-SIYQNCkzahaD3xt/PqIeLZD7N5JltF46d+x8TlJmqk0=";
  };

  sourceRoot = "${finalAttrs.src.name}/codex-rs";

  cargoHash = "sha256-9zk/XcPVnI9xfLPTlyAMpqblGVoyOa13QU8Zd5yKaCE=";

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
    installShellCompletion --cmd code \
      --bash <($out/bin/code completion bash) \
      --fish <($out/bin/code completion fish) \
      --zsh <($out/bin/code completion zsh)
  '';

  doInstallCheck = true;

  meta = {
    description = "Fork of codex. Orchestrate agents from OpenAI, Claude, Gemini or any provider.";
    homepage = "https://github.com/just-every/code/";
    changelog = "https://github.com/just-every/code/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.asl20;
    mainProgram = "code";
    platforms = lib.platforms.unix;
  };
})
