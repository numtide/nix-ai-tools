{
  lib,
  fetchurl,
  buildNpmPackage,
  makeWrapper,
  ripgrep,
  runCommand,
}:

let
  versionData = lib.importJSON ./hashes.json;
  version = versionData.version;

  # Create a source with the vendored package-lock.json included
  srcWithLock = runCommand "iflow-cli-src-with-lock" { } ''
    mkdir -p $out
    tar -xzf ${
      fetchurl {
        url = "https://registry.npmjs.org/@iflow-ai/iflow-cli/-/iflow-cli-${version}.tgz";
        hash = versionData.sourceHash;
      }
    } -C $out --strip-components=1
    cp ${./package-lock.json} $out/package-lock.json
  '';
in
buildNpmPackage {
  npmDepsFetcherVersion = 2;
  inherit version;
  pname = "iflow-cli";

  src = srcWithLock;

  npmDepsHash = versionData.npmDepsHash;
  makeCacheWritable = true;

  postPatch = ''
    # Disable auto-update: replace `process.env.DEV==="true"` with `true` in ybt()
    substituteInPlace bundle/iflow.js \
      --replace-fail 'process.env.DEV==="true"' 'true'
  '';

  npmFlags = [ "--ignore-scripts" ];

  nativeBuildInputs = [ makeWrapper ];

  dontNpmBuild = true;

  postInstall = ''
    wrapProgram $out/bin/iflow \
      --set USE_BUILTIN_RIPGREP 0 \
      --prefix PATH : ${lib.makeBinPath [ ripgrep ]}
  '';

  passthru.category = "AI Coding Agents";

  meta = {
    description = "AI coding agent for the terminal with free model access via the iFlow platform";
    homepage = "https://github.com/iflow-ai/iflow-cli";
    license = lib.licenses.asl20;
    sourceProvenance = with lib.sourceTypes; [ binaryBytecode ];
    mainProgram = "iflow";
    platforms = lib.platforms.all;
    maintainers = [ ];
  };
}
