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
  version = "1.22.5";

  src = fetchFromGitHub {
    owner = "Mote-Software";
    repo = "nanocoder";
    rev = "v${version}";
    hash = "sha256-i1QdMsrX9yyPXRl58TSFNRAW33F7uHL5efeFu6T7bCc=";
    postFetch = ''
      rm -f $out/pnpm-workspace.yaml
    '';
  };

  npmDeps = null;
  pnpmDeps = fetchPnpmDeps {
    inherit pname version src;
    inherit pnpm;
    fetcherVersion = 2;
    hash = "sha256-3Agc+XxRQjWJJjo8W0249iiIVZuYJ4FPzKahffbZ8bE=";
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
