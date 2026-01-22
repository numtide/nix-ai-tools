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
  version = "0.13.6";
  src = fetchurl {
    url = "https://registry.npmjs.org/@letta-ai/letta-code/-/letta-code-${version}.tgz";
    hash = "sha256-QnqAPjF2OIA+elTQyLS8pgNUsV3hBKX72icuROBmxuc=";
  };

  # Fetch package-lock.json from GitHub (main branch has it, releases don't)
  packageLock = fetchurl {
    url = "https://raw.githubusercontent.com/letta-ai/letta-code/main/package-lock.json";
    hash = "sha256-luckjVudtkGnu/n+g9HqJA2/D2+w7MhvfuaQSyjZnxM=";
  };

  # Add package-lock.json to the npm tarball
  srcWithLock = runCommand "letta-code-src-with-lock" { } ''
    mkdir -p $out
    tar -xzf ${src} -C $out --strip-components=1
    cp ${packageLock} $out/package-lock.json
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
    hash = "sha256-MogODpIvfjfvHJOkciCeWBlGNg06B2vW2wnKTkEv7Tc=";
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
