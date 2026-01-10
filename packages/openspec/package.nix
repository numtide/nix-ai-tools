{
  buildNpmPackage,
  fetchurl,
  lib,
  fetchNpmDepsWithPackuments,
  npmConfigHook,
  runCommand,
}:

let
  versionData = lib.importJSON ./hashes.json;
  version = versionData.version;
  # Create a source with the vendored package-lock.json included
  srcWithLock = runCommand "openspec-src-with-lock" { } ''
    mkdir -p $out
    tar -xzf ${
      fetchurl {
        url = "https://registry.npmjs.org/@fission-ai/openspec/-/openspec-${version}.tgz";
        hash = versionData.sourceHash;
      }
    } -C $out --strip-components=1
    cp ${./package-lock.json} $out/package-lock.json
  '';
in
buildNpmPackage {
  inherit npmConfigHook version;
  pname = "openspec";

  src = srcWithLock;

  npmDeps = fetchNpmDepsWithPackuments {
    src = srcWithLock;
    name = "openspec-${version}-npm-deps";
    hash = versionData.npmDepsHash;
    fetcherVersion = 2;
  };
  makeCacheWritable = true;

  dontNpmBuild = true;

  passthru.category = "Workflow & Project Management";

  meta = {
    description = "Spec-driven development for AI coding assistants";
    homepage = "https://github.com/Fission-AI/OpenSpec";
    downloadPage = "https://www.npmjs.com/package/@fission-ai/openspec";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryBytecode ];
    mainProgram = "openspec";
  };
}
