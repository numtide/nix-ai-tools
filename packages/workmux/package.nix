{
  lib,
  stdenv,
  rustPlatform,
  fetchFromGitHub,
  installShellFiles,
  versionCheckHook,
  versionCheckHomeHook,
}:

rustPlatform.buildRustPackage rec {
  pname = "workmux";
  version = "0.1.109";

  src = fetchFromGitHub {
    owner = "raine";
    repo = "workmux";
    rev = "v${version}";
    hash = "sha256-cyRAYAaNCxT39fFp1rxxqv/OI1a7rp4pCiKsk2fhnvU=";
  };

  cargoHash = "sha256-0OoZX3Etmxw28tF3CnUXXavvOiYp5qGvnzYOkVMrN6Q=";

  patches = [
    # Fix bash completion panic caused by __exec subcommand name.
    # clap_complete uses __ as delimiter, so subcommand names starting
    # with __ break the round-trip encoding. Rename to _exec.
    # https://github.com/raine/workmux/issues/14
    ./fix-bash-completion-panic.patch
  ];

  nativeBuildInputs = [ installShellFiles ];

  # Some tests require filesystem access outside the sandbox
  doCheck = false;

  postInstall = lib.optionalString (stdenv.buildPlatform.canExecute stdenv.hostPlatform) ''
    export HOME=$(mktemp -d)
    installShellCompletion --cmd workmux \
      --bash <($out/bin/workmux completions bash) \
      --fish <($out/bin/workmux completions fish) \
      --zsh <($out/bin/workmux completions zsh)
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];

  passthru.category = "Workflow & Project Management";

  meta = with lib; {
    description = "Git worktrees + tmux windows for zero-friction parallel dev";
    homepage = "https://github.com/raine/workmux";
    changelog = "https://github.com/raine/workmux/blob/v${version}/CHANGELOG.md";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [ fromSource ];
    mainProgram = "workmux";
    platforms = platforms.all;
  };
}
