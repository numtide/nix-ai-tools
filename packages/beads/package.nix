{
  lib,
  buildGoModule,
  fetchFromGitHub,
  unpinGoModVersionHook,
  versionCheckHook,
}:

buildGoModule rec {
  pname = "beads";
  version = "0.57.0";

  src = fetchFromGitHub {
    owner = "steveyegge";
    repo = "beads";
    rev = "v${version}";
    hash = "sha256-BjDuqadUtNMeiclWzRNnx/lXjUvHkj+F7J17VfCMEH0=";
  };

  vendorHash = "sha256-uf6ET13OImaGk22I9MJ/wJvX8F0bXaEkf726De/80PY=";

  nativeBuildInputs = [ unpinGoModVersionHook ];

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
