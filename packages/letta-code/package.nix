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
}:

let
  version = "0.13.8";
  # The npm tarball doesn't include package-lock.json, so we maintain our own
  # The upstream package-lock.json (added in commit 19680594) is out of date and not usable
  srcWithLock = runCommand "letta-code-src-with-lock" { } ''
    mkdir -p $out
    tar -xzf ${
      fetchurl {
        url = "https://registry.npmjs.org/@letta-ai/letta-code/-/letta-code-${version}.tgz";
        hash = "sha256-GK6a5To4tjg2mzbaMFdxFr0tyDUmgF6w3g/x/zM8GV8=";
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
    hash = "sha256-ZNkCkIYtOvK3xmnp6PTTpahIlPmLSzdcyCjcc1E6pzU=";
    fetcherVersion = 2;
  };
  makeCacheWritable = true;

  npmInstallFlags = [ "--ignore-scripts" ];
  npmRebuildFlags = [ "--ignore-scripts" ];

  # The package from npm is already built
  dontNpmBuild = true;

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
