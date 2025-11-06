{
  lib,
  buildGo125Module,
  fetchFromGitHub,
}:
buildGo125Module rec {
  pname = "crush";
  version = "0.15.1";

  src = fetchFromGitHub {
    owner = "charmbracelet";
    repo = "crush";
    rev = "v${version}";
    hash = "sha256-a9RCZsm4CY6itRNM+vEM0f46aug0GqB5ag77L3lu72Y=";
  };

  vendorHash = "sha256-OuvS/ZtIKiVf2yX73gMqRxtPGq4bxqUejcpUYdNCLL0=";

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
