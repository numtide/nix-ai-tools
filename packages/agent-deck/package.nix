{
  lib,
  flake,
  buildGoModule,
  fetchFromGitHub,
  versionCheckHook,
  versionCheckHomeHook,
  git,
}:

buildGoModule rec {
  pname = "agent-deck";
  version = "1.5.0";

  src = fetchFromGitHub {
    owner = "asheshgoplani";
    repo = "agent-deck";
    rev = "v${version}";
    hash = "sha256-0jOgTHlF2vx4fQC0V0sUyHAmi3YgNP3wydKiXp5pr9M=";
  };

  vendorHash = "sha256-xGf1KrSc0Jl75FqFjt5KJslQeVRQPFljqTxF7MphhNk=";

  subPackages = [ "cmd/agent-deck" ];

  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];

  doCheck = true;

  preCheck = ''
    export HOME=$(mktemp -d)
    export PATH="${git}/bin:$PATH"
  '';

  doInstallCheck = true;

  ldflags = [
    "-s"
    "-w"
    "-X=main.version=${version}"
    "-X=main.commit=v${version}"
    "-X=main.date=1970-01-01T00:00:00Z"
  ];

  passthru.category = "Workflow & Project Management";

  meta = with lib; {
    description = "Your AI agent command center";
    homepage = "https://github.com/asheshgoplani/agent-deck";
    changelog = "https://github.com/asheshgoplani/agent-deck/releases/tag/v${version}";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ garbas ];
    mainProgram = "agent-deck";
  };
}
