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
  version = "0.3.2";

  src = fetchFromGitHub {
    owner = "open-gitagent";
    repo = "gitagent";
    rev = "v${finalAttrs.version}";
    hash = "sha256-YFcsUxnhWj3A9itf/eylM4Os5eXSMakO/LmEi+MbKnw=";
  };

  npmDeps = fetchNpmDepsWithPackuments {
    inherit (finalAttrs) src;
    name = "${finalAttrs.pname}-${finalAttrs.version}-npm-deps";
    hash = "sha256-j0lhpHaPpSvdPSjrfZr/gxs+2fJPKTy58ICyMuZYINA=";
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
