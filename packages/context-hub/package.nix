{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  flake,
  fetchNpmDepsWithPackuments,
  npmConfigHook,
  versionCheckHook,
}:

let
  versionData = lib.importJSON ./hashes.json;
in
buildNpmPackage (finalAttrs: {
  inherit npmConfigHook;
  pname = "context-hub";
  inherit (versionData) version;

  src = fetchFromGitHub {
    owner = "andrewyng";
    repo = "context-hub";
    # upstream does not tag releases; rev/version maintained by update.py
    inherit (versionData) rev hash;
  };

  npmDeps = fetchNpmDepsWithPackuments {
    inherit (finalAttrs) src;
    name = "${finalAttrs.pname}-${finalAttrs.version}-npm-deps";
    hash = versionData.npmDepsHash;
    fetcherVersion = 2;
  };
  makeCacheWritable = true;

  dontNpmBuild = true;

  installPhase = ''
    runHook preInstall

    npm prune --omit=dev --no-audit --no-fund

    mkdir -p $out/lib/context-hub $out/bin
    cp -r cli node_modules package.json $out/lib/context-hub/
    rm -rf $out/lib/context-hub/cli/{test,tests}

    patchShebangs $out/lib/context-hub/cli/bin/

    ln -s $out/lib/context-hub/cli/bin/chub $out/bin/chub
    ln -s $out/lib/context-hub/cli/bin/chub-mcp $out/bin/chub-mcp

    runHook postInstall
  '';

  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckProgramArg = "--cli-version";
  doInstallCheck = true;

  passthru.category = "Utilities";

  meta = {
    description = "CLI for Context Hub - search and retrieve LLM-optimized docs and skills";
    homepage = "https://github.com/andrewyng/context-hub";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ murlakatam ];
    mainProgram = "chub";
    platforms = lib.platforms.all;
  };
})
