{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  flake,
}:

buildNpmPackage (finalAttrs: {
  pname = "openskills";
  version = "1.3.0";

  src = fetchFromGitHub {
    owner = "numman-ali";
    repo = "openskills";
    rev = "v${finalAttrs.version}";
    hash = "sha256-JLPxG8PbCSRLm6DFxSSbE94pf+Ur1ME5uF5f1z2Jhjw=";
  };

  npmDepsHash = "sha256-unmxbQHOHsKF0mGCPP1eSe2H1cm7nMsTwObkF9MN2yQ=";

  meta = {
    description = "Universal skills loader for AI coding agents - install and load Anthropic SKILL.md format skills in any agent";
    homepage = "https://github.com/numman-ali/openskills";
    license = lib.licenses.asl20;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ ypares ];
    mainProgram = "openskills";
    platforms = lib.platforms.all;
  };
})
