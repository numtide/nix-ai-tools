{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  flake,
}:

buildNpmPackage (finalAttrs: {
  npmDepsFetcherVersion = 2;
  pname = "gitagent";
  version = "1.4.3";

  src = fetchFromGitHub {
    owner = "open-gitagent";
    repo = "gitagent";
    rev = "v${finalAttrs.version}";
    hash = "sha256-OEhLqEBgcVQLvjrSN6cAagKStLi0VWfciFp17HjkAuU=";
  };

  npmDepsHash = "sha256-Hp9xHCNeNbl16qtJkK8LyF4TroIAuUzlT47vo2QLzL0=";
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
