{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule rec {
  pname = "crush";
  version = "0.4.0";

  src = fetchFromGitHub {
    owner = "charmbracelet";
    repo = "crush";
    rev = "v${version}";
    hash = "sha256-pd1fqM5TwHgLM4IAaGuJDtfKDziJ3x4RUAHYL4oa7jA=";
  };

  vendorHash = "sha256-PeorgBPtQsPUEpwReSsZqjIidkjfl4pyTg2iO0qcDAY=";

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
