{
  buildNpmPackage,
  fetchzip,
  lib,
}:
buildNpmPackage (finalAttrs: {
  pname = "openspec";
  version = "0.17.2";

  src = fetchzip {
    url = "https://registry.npmjs.org/@fission-ai/openspec/-/openspec-${finalAttrs.version}.tgz";
    hash = "sha256-ZrG3/LNIhE2RUpYz6ZqHpVKHYZ5jLmKpiWcxIeYfQXE=";
  };

  npmDepsHash = "sha256-xG2GIzgzFKzZd0TxHI6FNGKEtQB1zIrregdXGZSMYyo=";

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  dontNpmBuild = true;

  meta = {
    description = "Spec-driven development for AI coding assistants";
    homepage = "https://github.com/Fission-AI/OpenSpec";
    downloadPage = "https://www.npmjs.com/package/@fission-ai/openspec";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryBytecode ];
    mainProgram = "openspec";
  };
})
