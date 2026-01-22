{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  fetchNpmDepsWithPackuments,
  npmConfigHook,
  nodejs,
  versionCheckHook,
  versionCheckHomeHook,
}:

buildNpmPackage rec {
  inherit npmConfigHook nodejs;
  pname = "letta-code";
  version = "0.13.6-unstable-2026-01-22";

  src = fetchFromGitHub {
    owner = "letta-ai";
    repo = "letta-code";
    rev = "bf18792c9c6c35df78e978c1a21b0dd95b41fbb7";
    hash = "sha256-MuK3X5QkAjIVRXfSbifzdi1z8Y4HFs+REbTHXoitz4E=";
  };

  npmDeps = fetchNpmDepsWithPackuments {
    inherit src;
    name = "${pname}-${version}-npm-deps";
    hash = "sha256-MogODpIvfjfvHJOkciCeWBlGNg06B2vW2wnKTkEv7Tc=";
    fetcherVersion = 2;
  };
  makeCacheWritable = true;

  npmInstallFlags = [ "--ignore-scripts" ];
  npmRebuildFlags = [ "--ignore-scripts" ];

  # Need to build from source since GitHub doesn't include pre-built letta.js
  dontNpmBuild = false;

  # Use environment variables to forcefully disable all scripts
  NPM_CONFIG_IGNORE_SCRIPTS = "true";
  NPM_CONFIG_LEGACY_PEER_DEPS = "true";

  # patchShebangs will automatically fix the shebang in the installed binary
  # No need for manual postInstall sed commands

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];

  passthru.category = "AI Coding Agents";

  meta = with lib; {
    description = "Memory-first coding agent that learns and evolves across sessions";
    homepage = "https://github.com/letta-ai/letta-code";
    downloadPage = "https://www.npmjs.com/package/@letta-ai/letta-code";
    changelog = "https://github.com/letta-ai/letta-code/releases";
    license = licenses.asl20;
    sourceProvenance = with sourceTypes; [ binaryBytecode ];
    maintainers = with maintainers; [ vizid ];
    mainProgram = "letta";
    platforms = platforms.all;
  };
}
