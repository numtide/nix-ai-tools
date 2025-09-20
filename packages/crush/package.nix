{
  lib,
  buildGo125Module,
  fetchFromGitHub,
}:
buildGo125Module rec {
  pname = "crush";
  version = "0.9.2";

  src = fetchFromGitHub {
    owner = "charmbracelet";
    repo = "crush";
    rev = "v${version}";
    hash = "sha256-VFAGjNtXKNjkv8Ryi28oFN/uLomXXdw6NFtyjT3pMEY=";
  };

  vendorHash = "sha256-ktF3kIr143uPwiEbgafladZRqIsmG6jI2BeumGSu82U=";

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
