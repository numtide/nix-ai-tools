{
  lib,
  buildGoModule,
  fetchFromGitHub,
  go_1_24,
  versionCheckHook,
  versionCheckHomeHook,
  git,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version hash vendorHash;

  src = fetchFromGitHub {
    owner = "asheshgoplani";
    repo = "agent-deck";
    rev = "v${version}";
    inherit hash;
  };
in
(buildGoModule.override { go = go_1_24; }) {
  pname = "agent-deck";
  inherit version vendorHash src;

  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];

  doCheck = true;
  nativeCheckInputs = [ git ];
  preCheck = ''
    export HOME=$(mktemp -d)
  '';

  doInstallCheck = true;

  ldflags = [
    "-s"
    "-w"
    "-X=main.version=${version}"
    "-X=main.commit=${src.rev}"
    "-X=main.date=1970-01-01T00:00:00Z"
  ];

  passthru.category = "Workflow & Project Management";

  meta = with lib; {
    description = "Your AI agent command center";
    homepage = "https://github.com/asheshgoplani/agent-deck";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with lib.maintainers; [ garbas ];
    mainProgram = "agent-deck";
  };
}
