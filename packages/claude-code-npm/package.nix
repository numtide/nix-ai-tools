{
  lib,
  buildNpmPackage,
  fetchzip,
  makeWrapper,
  versionCheckHook,
  fetchNpmDepsWithPackuments,
  npmConfigHook,
  nodejs,
  runCommand,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version hash npmDepsHash;

  # Create a source with the vendored package-lock.json included
  src = runCommand "claude-code-npm-src-with-lock" { } ''
    mkdir -p $out
    cp -r ${
      fetchzip {
        url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${version}.tgz";
        inherit hash;
      }
    }/* $out/
    cp ${./package-lock.json} $out/package-lock.json
  '';
in
buildNpmPackage {
  inherit npmConfigHook nodejs;
  pname = "claude-code-npm";
  inherit version src;

  npmDeps = fetchNpmDepsWithPackuments {
    inherit src;
    name = "claude-code-npm-${version}-npm-deps";
    hash = npmDepsHash;
    fetcherVersion = 2;
  };
  makeCacheWritable = true;

  nativeBuildInputs = [ makeWrapper ];

  dontNpmBuild = true;

  AUTHORIZED = "1";

  # Disable auto-updates and telemetry by wrapping the binary
  postInstall = ''
    wrapProgram $out/bin/claude \
      --set DISABLE_AUTOUPDATER 1 \
      --set CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC 1 \
      --set DISABLE_NON_ESSENTIAL_MODEL_CALLS 1 \
      --set DISABLE_TELEMETRY 1 \
      --unset DEV
  '';

  doInstallCheck = true;

  nativeInstallCheckInputs = [ versionCheckHook ];

  meta = with lib; {
    description = "Agentic coding tool (Node.js/npm build for claudebox compatibility)";
    homepage = "https://github.com/anthropics/claude-code";
    downloadPage = "https://www.npmjs.com/package/@anthropic-ai/claude-code";
    changelog = "https://github.com/anthropics/claude-code/releases";
    license = licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with maintainers; [
      malo
      omarjatoi
    ];
    mainProgram = "claude";
    platforms = platforms.all;
  };
}
