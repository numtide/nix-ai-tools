{
  lib,
  fetchFromGitHub,
  rustPlatform,
  pkg-config,
  openssl,
  sqlite,
  installShellFiles,
  versionCheckHook,
  onnxruntime,
  stdenv,
}:

rustPlatform.buildRustPackage rec {
  pname = "coding-agent-search";
  version = "0.1.49";

  src = fetchFromGitHub {
    owner = "Dicklesworthstone";
    repo = "coding_agent_session_search";
    rev = "v${version}";
    hash = "sha256-ZQ9lTL5qOz++nVtrEY6kFw730hcC6anTBPy8EnOCCco=";
  };

  cargoHash = "sha256-R9WOo7nMZPnZWr8S6gR6+Xk+xIvVY5Fl9Yqa/wuy0is=";

  nativeBuildInputs = [
    pkg-config
    installShellFiles
  ];

  buildInputs = [
    openssl
    sqlite
    onnxruntime
  ];

  # Point ort-sys to nixpkgs onnxruntime
  preBuild = ''
    export ORT_SKIP_DOWNLOAD=1
    export ORT_LIB_LOCATION=${onnxruntime}/lib
  '';

  # The main binary is cass
  cargoBuildFlags = [
    "--bin"
    "cass"
  ];

  # Tests require a writable HOME directory
  doCheck = false;

  postInstall = lib.optionalString (stdenv.buildPlatform.canExecute stdenv.hostPlatform) ''
    # Generate shell completions
    $out/bin/cass completions bash > cass.bash && installShellCompletion --bash cass.bash
    $out/bin/cass completions fish > cass.fish && installShellCompletion --fish cass.fish
    $out/bin/cass completions zsh > cass.zsh && installShellCompletion --zsh cass.zsh

    # Generate man page
    $out/bin/cass man > cass.1
    installManPage cass.1
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  meta = with lib; {
    description = "Unified, high-performance TUI to index and search your local coding agent history";
    longDescription = ''
      coding-agent-search (cass) aggregates sessions from Codex, Claude Code,
      Gemini CLI, Cline, OpenCode, Amp, Cursor, ChatGPT, Aider, and Pi-Agent
      into a single, searchable timeline with instant full-text search.

      This build includes ONNX Runtime for optional semantic search functionality.
    '';
    homepage = "https://github.com/Dicklesworthstone/coding_agent_session_search";
    changelog = "https://github.com/Dicklesworthstone/coding_agent_session_search/blob/main/CHANGELOG.md";
    downloadPage = "https://github.com/Dicklesworthstone/coding_agent_session_search/releases";
    license = licenses.mit;
    platforms = platforms.unix;
    sourceProvenance = with sourceTypes; [ fromSource ];
    mainProgram = "cass";
  };
}
