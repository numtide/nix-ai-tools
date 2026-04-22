{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  flake,
  fetchNpmDepsWithPackuments,
  npmConfigHook,
}:

buildNpmPackage (finalAttrs: {
  inherit npmConfigHook;
  pname = "context-hub";
  version = "0.1.3";

  src = fetchFromGitHub {
    owner = "andrewyng";
    repo = "context-hub";
    rev = "596506ebb4d53cfbc6ae458b731e0b1a18790f9e";
    hash = "sha256-ozn5yrdtoPqcw/PiHJLHXT4Ayyed1AS1zak5a83pIQA=";
  };

  npmDeps = fetchNpmDepsWithPackuments {
    inherit (finalAttrs) src;
    name = "${finalAttrs.pname}-${finalAttrs.version}-npm-deps";
    hash = "sha256-6aejmBVNztS8kAX9eq9HwfPJK6DwOCD3X6rQ5ZMQAmM=";
    fetcherVersion = 2;
  };
  makeCacheWritable = true;

  dontNpmBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/context-hub $out/bin
    cp -r cli node_modules package.json package-lock.json $out/lib/context-hub/

    patchShebangs $out/lib/context-hub/cli/bin/

    ln -s $out/lib/context-hub/cli/bin/chub $out/bin/chub
    ln -s $out/lib/context-hub/cli/bin/chub-mcp $out/bin/chub-mcp

    runHook postInstall
  '';

  passthru.category = "Utilities";

  meta = {
    description = "CLI for Context Hub - search and retrieve LLM-optimized docs and skills";
    homepage = "https://github.com/andrewyng/context-hub";
    changelog = "https://github.com/andrewyng/context-hub/releases";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ murlakatam ];
    mainProgram = "chub";
    platforms = lib.platforms.all;
  };
})
