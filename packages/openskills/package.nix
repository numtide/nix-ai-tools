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
  version = "1.5.0";

  src = fetchFromGitHub {
    owner = "numman-ali";
    repo = "openskills";
    rev = "v${finalAttrs.version}";
    hash = "sha256-rOrLi43J+w6XBRZYYwlDPl8RqU7Zhr45B9UyP6Xarj0=";
  };

  npmDeps = fetchNpmDepsWithPackuments {
    inherit (finalAttrs) src;
    name = "${finalAttrs.pname}-${finalAttrs.version}-npm-deps";
    hash = "sha256-ZYiY66PKF7hAnFkw3RQ5xBw7L9WZx0giUhgE8ySE0Xw=";
    fetcherVersion = 2;
  };
  makeCacheWritable = true;

  passthru.category = "Utilities";

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
