{
  lib,
  flake,
  fetchFromGitHub,
  rustPlatform,
  git,
  versionCheckHook,
}:

rustPlatform.buildRustPackage rec {
  pname = "claw-code";
  version = "0-unstable-2026-04-13";

  src = fetchFromGitHub {
    owner = "ultraworkers";
    repo = "claw-code";
    rev = "e874bc6a4467158d91d644783c497c8eca472874";
    hash = "sha256-7CglaxUMiy67eG+M8A5SzdTDSCCL+4oN1IhCzBhAJ94=";
  };

  sourceRoot = "source/rust";

  cargoHash = "sha256-P8QqUM1s/fNv7Fb4dmpJWDfTNumgUu1Cdiln8ybSDUU=";

  cargoBuildFlags = [
    "--package"
    "rusty-claude-cli"
  ];
  cargoTestFlags = cargoBuildFlags;

  nativeCheckInputs = [ git ];

  preCheck = ''
    export HOME=$TMPDIR
  '';

  checkFlags = [
    # broken upstream at this rev: tool allow-list assertions out of sync with implementation
    "--skip=tests::rejects_unknown_allowed_tools"
    "--skip=tests::build_runtime_plugin_state_discovers_mcp_tools_and_surfaces_pending_servers"
    # integration harness expects scripted plugin fixtures not present in sandbox
    "--skip=clean_env_cli_reaches_mock_anthropic_service_across_scripted_parity_scenarios"
  ];

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckProgramArg = [ "--version" ];

  passthru.category = "AI Coding Agents";

  meta = {
    description = "Claude Code rewrite CLI built from the official claw-code Rust workspace";
    homepage = "https://github.com/ultraworkers/claw-code";
    changelog = "https://github.com/ultraworkers/claw-code/releases";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ smdex ];
    mainProgram = "claw";
    platforms = lib.platforms.unix;
  };
}
