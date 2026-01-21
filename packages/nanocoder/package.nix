{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  fetchPnpmDeps,
  pnpm,
  pnpmConfigHook,
  versionCheckHook,
}:

buildNpmPackage rec {
  pname = "nanocoder";
  version = "1.21.0";

  src = fetchFromGitHub {
    owner = "Mote-Software";
    repo = "nanocoder";
    rev = "v${version}";
    hash = "sha256-w6RM9x3VCZbn3YN6ChCX2DgkB8Izjd2TMw1dSbP59Uc=";
    postFetch = ''
      rm -f $out/pnpm-workspace.yaml
    '';
  };

  npmDeps = null;
  pnpmDeps = fetchPnpmDeps {
    inherit pname version src;
    inherit pnpm;
    fetcherVersion = 2;
    hash = "sha256-yPRI8MBchARoH65+ssmETE8lHzm7z9M4MiX25NQA3hQ=";
  };

  nativeBuildInputs = [ pnpm ];
  npmConfigHook = pnpmConfigHook;

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  dontNpmPrune = true; # hangs forever on both Linux/darwin

  passthru.category = "AI Coding Agents";

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
