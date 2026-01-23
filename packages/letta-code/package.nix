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
  version = "0.13.8";

  src = fetchFromGitHub {
    owner = "letta-ai";
    repo = "letta-code";
    rev = "v${version}";
    hash = "sha256-oYZPbxws5ayYVxrA8XtR+KMpGeVuq5icoB66NlcRu/I=";
  };

  npmDeps = fetchNpmDepsWithPackuments {
    inherit src;
    name = "${pname}-${version}-npm-deps";
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    fetcherVersion = 2;
  };

  npmInstallFlags = [ "--ignore-scripts" ];
  npmRebuildFlags = [ "--ignore-scripts" ];

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
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with maintainers; [ vizid ];
    mainProgram = "letta";
    platforms = platforms.all;
  };
}
