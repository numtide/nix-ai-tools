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
  pname = "gitagent";
  version = "0.2.0";

  src = fetchFromGitHub {
    owner = "open-gitagent";
    repo = "gitagent";
    rev = "v${finalAttrs.version}";
    hash = "sha256-gZG6sBXMCtsDiiX1sfH1G3m481L5uAr3zEW56kqqskE=";
  };

  npmDeps = fetchNpmDepsWithPackuments {
    inherit (finalAttrs) src;
    name = "${finalAttrs.pname}-${finalAttrs.version}-npm-deps";
    hash = "sha256-kpN9qoAt6LWYshK9ERILpqGSRAVsqY1kiJCw48loFp0=";
    fetcherVersion = 2;
  };
  makeCacheWritable = true;

  passthru.category = "Utilities";

  meta = {
    description = "Framework-agnostic, git-native standard for defining AI agents";
    homepage = "https://github.com/open-gitagent/gitagent";
    changelog = "https://github.com/open-gitagent/gitagent/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ mulatta ];
    mainProgram = "gitagent";
    platforms = lib.platforms.all;
  };
})
