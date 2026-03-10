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
  version = "0.21.0";

  src = fetchFromGitHub {
    owner = "zed-industries";
    repo = "claude-code-acp";
    rev = "v${version}";
    hash = "sha256-6c6bHuso3diW5ZfHiM2xcxGDTNG0LIL0TZd0MFVpW/E=";
  };

  npmDeps = fetchNpmDepsWithPackuments {
    inherit src;
    name = "${pname}-${version}-npm-deps";
    hash = "sha256-uE9wTK4i1DTS9VD14ua+7wo0h3lF1SAwYXqPUnZSUrc=";
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
    mainProgram = "claude-code-acp";
    platforms = platforms.all;
  };
}
