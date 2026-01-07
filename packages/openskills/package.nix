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
  pname = "openskills";
  version = "1.3.0";

  src = fetchFromGitHub {
    owner = "numman-ali";
    repo = "openskills";
    rev = "v${finalAttrs.version}";
    hash = "sha256-JLPxG8PbCSRLm6DFxSSbE94pf+Ur1ME5uF5f1z2Jhjw=";
  };

  npmDeps = fetchNpmDepsWithPackuments {
    inherit (finalAttrs) src;
    name = "${finalAttrs.pname}-${finalAttrs.version}-npm-deps";
    hash = "sha256-9psXGhPJMj1xDSkUoPyWC72bWpeiZm2aRVWvjF9t5RE=";
    fetcherVersion = 2;
  };
  makeCacheWritable = true;

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
