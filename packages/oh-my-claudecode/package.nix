{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  flake,
  fetchNpmDepsWithPackuments,
  npmConfigHook,
  versionCheckHook,
}:

buildNpmPackage (finalAttrs: {
  inherit npmConfigHook;
  pname = "oh-my-claudecode";
  version = "4.13.1";

  src = fetchFromGitHub {
    owner = "yeachan-heo";
    repo = "oh-my-claudecode";
    rev = "v${finalAttrs.version}";
    hash = "sha256-C/m8Vlt6MXy8nlgqtoey9A5JnVTHCPkGUjar9x5Y2uw=";
  };

  npmDeps = fetchNpmDepsWithPackuments {
    inherit (finalAttrs) src;
    name = "${finalAttrs.pname}-${finalAttrs.version}-npm-deps";
    hash = "sha256-XeyJSt1J0dGHZMb5Rzb8zPqoNTyy0GOj8J/cnbgSAfw=";
    fetcherVersion = 2;
  };
  makeCacheWritable = true;

  # Native deps (better-sqlite3, @ast-grep/napi) need rebuild skipped
  npmFlags = [ "--ignore-scripts" ];

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  passthru.category = "Claude Code Ecosystem";

  meta = {
    description = "Multi-agent orchestration system for Claude Code";
    homepage = "https://github.com/yeachan-heo/oh-my-claudecode";
    changelog = "https://github.com/yeachan-heo/oh-my-claudecode/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ murlakatam ];
    mainProgram = "oh-my-claudecode";
    platforms = lib.platforms.all;
  };
})
