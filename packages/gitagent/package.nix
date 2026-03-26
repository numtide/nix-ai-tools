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
  version = "0.1.7";

  src = fetchFromGitHub {
    owner = "open-gitagent";
    repo = "gitagent";
    rev = "v${finalAttrs.version}";
    hash = "sha256-gL6mq6DR95O6dnrylizDd+BhHiVgHXHtoqJ09hxe0Tc=";
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
