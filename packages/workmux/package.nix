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
  version = "0.1.178";

  src = fetchFromGitHub {
    owner = "raine";
    repo = "workmux";
    rev = "v${version}";
    hash = "sha256-hhHWjcYkqHM5IdYYzSnqCCpbWM3j9igh1xLoDuCCgjI=";
  };

  cargoHash = "sha256-QSYNDNdFu9h1ueueFxGFUoSZeNz/6n0gjHYMY/lMNB8=";

  nativeBuildInputs = [ installShellFiles ];

  # Some tests require filesystem access outside the sandbox
  doCheck = false;

  postInstall =
    lib.optionalString (stdenv.buildPlatform.canExecute stdenv.hostPlatform) ''
      export HOME=$(mktemp -d)
      installShellCompletion --cmd workmux \
        --bash <($out/bin/workmux completions bash) \
        --fish <($out/bin/workmux completions fish) \
        --zsh <($out/bin/workmux completions zsh)
    ''
    + ''
      # Install Claude Code skills shipped with workmux so users can
      # symlink $out/share/workmux/skills/* into ~/.claude/skills/
      install -d $out/share/workmux
      cp -r skills $out/share/workmux/skills
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
