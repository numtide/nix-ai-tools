{
  lib,
  buildGoModule,
  fetchFromGitHub,
  versionCheckHook,
}:

buildGoModule rec {
  pname = "beads";
  version = "0.47.1";

  src = fetchFromGitHub {
    owner = "steveyegge";
    repo = "beads";
    rev = "v${version}";
    hash = "sha256-DwIR/r1TJnpVd/CT1E2OTkAjU7k9/KHbcVwg5zziFVg=";
  };

  vendorHash = "sha256-pY5m5ODRgqghyELRwwxOr+xlW41gtJWLXaW53GlLaFw=";

  subPackages = [ "cmd/bd" ];

  doCheck = false;

  doInstallCheck = true;

  nativeInstallCheckInputs = [ versionCheckHook ];

  passthru.category = "Workflow & Project Management";

  meta = with lib; {
    description = "A distributed issue tracker designed for AI-supervised coding workflows";
    homepage = "https://github.com/steveyegge/beads";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with maintainers; [ zimbatm ];
    mainProgram = "bd";
    platforms = platforms.unix;
  };
}
