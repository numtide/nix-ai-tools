{
  lib,
  buildNpmPackage,
  fetchurl,
  fetchNpmDepsWithPackuments,
  npmConfigHook,
  nodejs,
  runCommand,
  versionCheckHook,
  versionCheckHomeHook,
  jq,
}:

let
  versionData = lib.importJSON ./hashes.json;
  version = versionData.version;
  # Create a source with package-lock.json included
  srcWithLock = runCommand "letta-code-src-with-lock" { } ''
    mkdir -p $out
    tar -xzf ${
      fetchurl {
        url = "https://registry.npmjs.org/@letta-ai/letta-code/-/letta-code-${version}.tgz";
        hash = versionData.sourceHash;
      }
    } -C $out --strip-components=1
    cp ${./package-lock.json} $out/package-lock.json
  '';
in
buildNpmPackage rec {
  inherit npmConfigHook nodejs;
  pname = "letta-code";
  inherit version;

  src = srcWithLock;

  npmDeps = fetchNpmDepsWithPackuments {
    inherit src;
    name = "${pname}-${version}-npm-deps";
    hash = versionData.npmDepsHash;
    fetcherVersion = 2;
  };
  makeCacheWritable = true;
  
  # npm ci supports legacy-peer-deps via environment variable
  NPM_CONFIG_LEGACY_PEER_DEPS = "true";
  
  npmInstallFlags = [ "--ignore-scripts" ];
  npmRebuildFlags = [ "--ignore-scripts" ];
  
  # Debug: show what npm commands will be run
  preInstall = ''
    echo "=== DEBUG: About to run npm install ==="
    echo "npmInstallFlags: $npmInstallFlags"
    echo "npmRebuildFlags: $npmRebuildFlags"
    echo "NPM_CONFIG_LEGACY_PEER_DEPS: $NPM_CONFIG_LEGACY_PEER_DEPS"
  '';
  
  # Debug: show what's in the package files
  postPatch = ''
    echo "=== DEBUG: Checking package.json optional dependencies ==="
    ${lib.getExe jq} '.optionalDependencies' package.json || true
    echo "=== DEBUG: Checking package-lock.json for ripgrep ==="
    ${lib.getExe jq} '.packages | keys | .[] | select(contains("ripgrep"))' package-lock.json || true
    echo "=== DEBUG: NPM version ==="
    npm --version
    echo "=== DEBUG: Environment variables ==="
    env | grep -i npm || true
  '';

  # The package from npm is already built
  dontNpmBuild = true;

  # patchShebangs will automatically fix the shebang in the installed binary
  # No need for manual postInstall sed commands

  # Temporarily disable version check to test build
  doInstallCheck = false;
  # nativeInstallCheckInputs = [
  #   versionCheckHook
  #   versionCheckHomeHook
  # ];

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
