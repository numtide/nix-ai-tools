{
  lib,
  buildNpmPackage,
  fetchzip,
  versionCheckHook,
  fetchNpmDepsWithPackuments,
  npmConfigHook,
  nodejs,
  runCommand,
  makeWrapper,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version hash npmDepsHash;

  # Create a source with the vendored package-lock.json included
  src = runCommand "copilot-language-server-src-with-lock" { } ''
    mkdir -p $out
    cp -r ${
      fetchzip {
        url = "https://registry.npmjs.org/@github/copilot-language-server/-/copilot-language-server-${version}.tgz";
        inherit hash;
      }
    }/* $out/
    cp ${./package-lock.json} $out/package-lock.json
  '';
in
buildNpmPackage {
  inherit npmConfigHook nodejs;
  pname = "copilot-language-server";
  inherit version src;

  npmDeps = fetchNpmDepsWithPackuments {
    inherit src;
    name = "copilot-language-server-${version}-npm-deps";
    hash = npmDepsHash;
    fetcherVersion = 2;
  };
  makeCacheWritable = true;

  nativeBuildInputs = [ makeWrapper ];

  # Skip optional platform-specific dependencies (not needed with Node.js 22+)
  npmFlags = [
    "--ignore-scripts"
    "--omit=optional"
  ];

  dontNpmBuild = true;

  # Fix the broken bin wrapper path created by npm for scoped packages
  postInstall = ''
    rm -rf $out/bin
    mkdir -p $out/bin
    makeWrapper ${nodejs}/bin/node $out/bin/copilot-language-server \
      --add-flags "$out/lib/node_modules/@github/copilot-language-server/dist/language-server.js"
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  passthru.category = "Utilities";

  meta = with lib; {
    description = "GitHub Copilot Language Server - AI pair programmer LSP";
    homepage = "https://github.com/github/copilot-language-server-release";
    downloadPage = "https://www.npmjs.com/package/@github/copilot-language-server";
    license = licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryBytecode ];
    mainProgram = "copilot-language-server";
    platforms = platforms.all;
  };
}
