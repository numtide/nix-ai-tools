{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  pnpm_9,
}:

buildNpmPackage rec {
  pname = "nanocoder";
  version = "1.13.5";

  src = fetchFromGitHub {
    owner = "Mote-Software";
    repo = "nanocoder";
    rev = "v${version}";
    hash = "sha256-OJ/vbgX4sEvTtxeBRjXa4S5DaOglEpQufS2sGK+fLyM=";
    postFetch = ''
      rm -f $out/pnpm-workspace.yaml
    '';
  };

  npmConfigHook = pnpm_9.configHook;
  npmDeps = pnpmDeps;
  pnpmDeps = pnpm_9.fetchDeps {
    inherit pname version src;
    fetcherVersion = 2;
    hash = "sha256-G4LSqp+GbcL4Bqcdurj6eYwPCcRHQelG8TAmC63tA8M=";
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
