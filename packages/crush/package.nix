{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule rec {
  pname = "crush";
  version = "0.1.8";

  src = fetchFromGitHub {
    owner = "charmbracelet";
    repo = "crush";
    rev = "v${version}";
    hash = "sha256-qx3McjTvNH/8Rmgnk4c2+dnSb7I/XJNLrab0miFdq3w=";
  };

  vendorHash = "sha256-AlZg0YOqLsCmBeszfRCYit18tWYsuS0/ktxbaur4VsQ=";

  # Tests require config files that aren't available in the build environment
  doCheck = false;

  ldflags = [
    "-s"
    "-w"
    "-X=github.com/charmbracelet/crush/internal/version.Version=${version}"
  ];

  meta = {
    description = "The glamourous AI coding agent for your favourite terminal";
    homepage = "https://github.com/charmbracelet/crush";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ zimbatm ];
    mainProgram = "crush";
  };
}
