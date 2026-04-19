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
  version = "0-unstable-2026-04-17";

  src = fetchFromGitHub {
    owner = "ultraworkers";
    repo = "claw-code";
    rev = "00d0eb61d4cfc1abd345dc76023dd21e420f6488";
    hash = "sha256-P8IUDkZ/+sTadHbk6pEguMo5D0MzQp5E28UAVFr2Nd4=";
  };

  sourceRoot = "source/rust";

  patches = [
    # init::tests share a temp dir when SystemTime nanos collide between
    # parallel test threads (observed on aarch64-darwin in the sandbox).
    # Upstreamable; drop once merged.
    ./init-tests-unique-tmpdir.patch
  ];

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
  versionCheckProgramArg = "--version";
  # Upstream has no tagged release yet; we track an unstable rev. The binary
  # reports the Cargo workspace.package.version (e.g. 0.1.0), so compare
  # against that rather than our `0-unstable-<date>` derivation version.
  preVersionCheck = ''
    version=$(sed -n 's/^version = "\(.*\)"/\1/p' Cargo.toml | head -n1)
  '';

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
