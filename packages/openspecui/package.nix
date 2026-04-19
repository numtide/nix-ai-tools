{
  buildNpmPackage,
  fetchurl,
  flake,
  jq,
  lib,
  fetchNpmDepsWithPackuments,
  npmConfigHook,
  runCommand,
}:

let
  versionData = lib.importJSON ./hashes.json;
  version = versionData.version;
  # Create a source with the vendored package-lock.json included
  # Strip devDependencies which contain workspace:* references that npm cannot resolve
  srcWithLock = runCommand "openspecui-src-with-lock" { nativeBuildInputs = [ jq ]; } ''
    mkdir -p $out
    tar -xzf ${
      fetchurl {
        url = "https://registry.npmjs.org/openspecui/-/openspecui-${version}.tgz";
        hash = versionData.sourceHash;
      }
    } -C $out --strip-components=1
    jq 'del(.devDependencies)' $out/package.json > $out/package.json.tmp
    mv $out/package.json.tmp $out/package.json
    cp ${./package-lock.json} $out/package-lock.json
  '';
in
buildNpmPackage {
  inherit npmConfigHook version;
  pname = "openspecui";

  src = srcWithLock;

  npmDeps = fetchNpmDepsWithPackuments {
    src = srcWithLock;
    name = "openspecui-${version}-npm-deps";
    hash = versionData.npmDepsHash;
    fetcherVersion = 2;
  };
  makeCacheWritable = true;

  dontNpmBuild = true;

  passthru.category = "Workflow & Project Management";

  meta = {
    description = "Visual interface for spec-driven development";
    homepage = "https://github.com/jixoai/openspecui";
    changelog = "https://github.com/jixoai/openspecui/releases/tag/v${version}";
    downloadPage = "https://www.npmjs.com/package/openspecui";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryBytecode ];
    maintainers = with flake.lib.maintainers; [ afterthought ];
    mainProgram = "openspecui";
  };
}
