{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  pnpm_9,
}:

buildNpmPackage rec {
  pname = "nanocoder";
  version = "1.14.1";

  src = fetchFromGitHub {
    owner = "Mote-Software";
    repo = "nanocoder";
    rev = "v${version}";
    hash = "sha256-y0BdcLfnQaxefZXGKsS+TdLOJtR+4A/xnc+waOCAxks=";
    postFetch = ''
      rm -f $out/pnpm-workspace.yaml
    '';
  };

  npmConfigHook = pnpm_9.configHook;
  npmDeps = pnpmDeps;
  pnpmDeps = pnpm_9.fetchDeps {
    inherit pname version src;
    fetcherVersion = 2;
    hash = "sha256-7lDCQXdPB9OCjMymd6FZxyCrKQ8vkRPT0SQ9afxz5LI=";
  };

  dontNpmPrune = true; # hangs forever on both Linux/darwin

  meta = with lib; {
    description = "A beautiful local-first coding agent running in your terminal - built by the community for the community ⚒";
    homepage = "https://github.com/Mote-Software/nanocoder";
    changelog = "https://github.com/Mote-Software/nanocoder/releases";
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    license = licenses.mit;
    platforms = platforms.all;
    mainProgram = "nanocoder";
  };
}
