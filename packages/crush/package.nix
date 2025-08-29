{
  lib,
  buildGo125Module,
  fetchFromGitHub,
}:
buildGo125Module rec {
  pname = "crush";
  version = "0.7.4";

  src = fetchFromGitHub {
    owner = "charmbracelet";
    repo = "crush";
    rev = "v${version}";
    hash = "sha256-UWrvMPti+d0O7+22QMO8LjoRITNbDcKGf9oKbo40Lx0=";
  };

  vendorHash = "sha256-CXjQtc8DXGb15Qz3RSkE7S7uL3h2k3g6fuO8L1znSJ0=";

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
