{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule rec {
  pname = "crush";
  version = "0.3.0";

  src = fetchFromGitHub {
    owner = "charmbracelet";
    repo = "crush";
    rev = "v${version}";
    hash = "sha256-0FzMNqSG/JjbdvVUaWlnZQvU3E1PWBG8968d3/mg4XE=";
  };

  vendorHash = "sha256-v04C77HvBpIpzZ8ehwwfG9guaE2k40TaSXPK3nahMM0=";

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
