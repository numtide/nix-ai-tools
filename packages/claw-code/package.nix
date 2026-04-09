{
  lib,
  flake,
  fetchFromGitHub,
  rustPlatform,
  versionCheckHook,
}:

rustPlatform.buildRustPackage rec {
  pname = "claw-code";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "ultraworkers";
    repo = "claw-code";
    rev = "4f670e5513db1ed485e8c822ef404a48e8129028";
    hash = "sha256-qghvVytVPV8/WDMEKRGGMYN+CPG1+aQepXgtJ3ibDVA=";
  };

  sourceRoot = "source/rust";

  cargoHash = "sha256-P8QqUM1s/fNv7Fb4dmpJWDfTNumgUu1Cdiln8ybSDUU=";

  cargoBuildFlags = [
    "--package"
    "rusty-claude-cli"
  ];

  doCheck = false;

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
