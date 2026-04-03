{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  fetchNpmDepsWithPackuments,
  npmConfigHook,
}:

buildNpmPackage rec {
  inherit npmConfigHook;
  pname = "claude-code-acp";
  version = "0.25.0";

  src = fetchFromGitHub {
    owner = "zed-industries";
    repo = "claude-code-acp";
    rev = "v${version}";
    hash = "sha256-RaVBdFnga/3Ra1EW8v2K/vl65vTK8k8MZFjzFyYQk/k=";
  };

  npmDeps = fetchNpmDepsWithPackuments {
    inherit src;
    name = "${pname}-${version}-npm-deps";
    hash = "sha256-Wo7Aa4i99oiBHWl1kuF/9l7Nvt9/Mofu0bB/R4UOCMc=";
    fetcherVersion = 2;
  };
  makeCacheWritable = true;

  # Disable install scripts to avoid platform-specific dependency fetching issues
  npmFlags = [ "--ignore-scripts" ];

  passthru.category = "ACP Ecosystem";

  meta = with lib; {
    description = "An ACP-compatible coding agent powered by the Claude Code SDK (TypeScript)";
    homepage = "https://github.com/zed-industries/claude-code-acp";
    changelog = "https://github.com/zed-industries/claude-code-acp/releases/tag/v${version}";
    license = licenses.asl20;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with maintainers; [ ];
    mainProgram = "claude-agent-acp";
    platforms = platforms.all;
  };
}
