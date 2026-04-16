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
  version = "0.29.0";

  src = fetchFromGitHub {
    owner = "zed-industries";
    repo = "claude-code-acp";
    rev = "v${version}";
    hash = "sha256-L2Kq4Lk5gHqE9rpBnrKcWXMaSQqEZHtcayjGnK4fYEQ=";
  };

  npmDeps = fetchNpmDepsWithPackuments {
    inherit src;
    name = "${pname}-${version}-npm-deps";
    hash = "sha256-odjNr3kYjSd0jMC7fhYLk3/kK1DcJjNMBOwfaHIa5tg=";
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
