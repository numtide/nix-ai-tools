{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  flake,
}:

buildNpmPackage (finalAttrs: {
  npmDepsFetcherVersion = 2;
  pname = "openskills";
  version = "1.5.0";

  src = fetchFromGitHub {
    owner = "numman-ali";
    repo = "openskills";
    rev = "v${finalAttrs.version}";
    hash = "sha256-rOrLi43J+w6XBRZYYwlDPl8RqU7Zhr45B9UyP6Xarj0=";
  };

  npmDepsHash = "sha256-ZYiY66PKF7hAnFkw3RQ5xBw7L9WZx0giUhgE8ySE0Xw=";
  makeCacheWritable = true;

  passthru.category = "Utilities";

  meta = {
    description = "Universal skills loader for AI coding agents - install and load Anthropic SKILL.md format skills in any agent";
    homepage = "https://github.com/numman-ali/openskills";
    changelog = "https://github.com/numman-ali/openskills/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.asl20;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ ypares ];
    mainProgram = "openskills";
    platforms = lib.platforms.all;
  };
})
