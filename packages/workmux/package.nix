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
  version = "0.1.140";

  src = fetchFromGitHub {
    owner = "raine";
    repo = "workmux";
    rev = "v${version}";
    hash = "sha256-q8mFEeiiyRwWWkUdNIp9jOk5aKgdtgSzckLqM3PM340=";
  };

  cargoHash = "sha256-jvVXv0FJ+ogQl1pVMgF1O531vDO/g6RNmTjlE306oEw=";

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
