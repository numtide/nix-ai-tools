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
  version = "0.12.6";

  src = fetchFromGitHub {
    owner = "zed-industries";
    repo = "claude-code-acp";
    rev = "v${version}";
    hash = "sha256-RJ3nl86fGEEh4RgZoLiyz9XOC4wlP7WxuJzavZLsjMI=";
  };

  npmDeps = fetchNpmDepsWithPackuments {
    inherit src;
    name = "${pname}-${version}-npm-deps";
    hash = "sha256-/VAgv7zoTSK131MhaRu7OKXWVgHfW95bHp/tAXQ3pFo=";
    fetcherVersion = 2;
  };
  makeCacheWritable = true;

  # Disable install scripts to avoid platform-specific dependency fetching issues
  npmFlags = [ "--ignore-scripts" ];

  passthru.category = "Claude Code Ecosystem";

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
