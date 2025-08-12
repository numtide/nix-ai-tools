{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule rec {
  pname = "crush";
  version = "0.5.0";

  src = fetchFromGitHub {
    owner = "charmbracelet";
    repo = "crush";
    rev = "v${version}";
    hash = "sha256-u2w19Xmcm3cx/B8QRNGaP2qeg+Cif/L92RNlJav6H3w=";
  };

  vendorHash = "sha256-H92TgZoWdYQ863AAb2116zJtmgkKXh2hRoEBRcn5zeA=";

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
