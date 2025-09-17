{
  lib,
  buildGo125Module,
  fetchFromGitHub,
}:
buildGo125Module rec {
  pname = "crush";
  version = "0.8.3";

  src = fetchFromGitHub {
    owner = "charmbracelet";
    repo = "crush";
    rev = "v${version}";
    hash = "sha256-NKGMI7NXnzQcECeSex5SifqhqPMYUVtPbFCeoHw7kgA=";
  };

  vendorHash = "sha256-b5RRCN5TxiGeFR0xQJ4wVg7K67tbqqJHThPS8XlArxE=";

  # Tests require config files that aren't available in the build environment
  doCheck = false;

  ldflags = [
    "-s"
    "-w"
    "-X=github.com/charmbracelet/crush/internal/version.Version=${version}"
  ];

  meta = with lib; {
    description = "The glamourous AI coding agent for your favourite terminal";
    homepage = "https://github.com/charmbracelet/crush";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with lib.maintainers; [ zimbatm ];
    mainProgram = "crush";
  };
}
