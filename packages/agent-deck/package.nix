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
  version = "0.26.4";

  src = fetchFromGitHub {
    owner = "asheshgoplani";
    repo = "agent-deck";
    rev = "v${version}";
    hash = "sha256-XEZKuKN/M1z47Fam0xLqwbIe1Tir8CH3aHsNyQP0Tgs=";
  };

  vendorHash = "sha256-PrhxSMJm4TPRtNHkg36HQJE4a0UDfYUpQdYA0tUor9k=";

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
