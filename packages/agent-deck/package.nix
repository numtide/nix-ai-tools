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
  version = "0.18.2";

  src = fetchFromGitHub {
    owner = "asheshgoplani";
    repo = "agent-deck";
    rev = "v${version}";
    hash = "sha256-S4ICCeJ9NOBSJRTvC6U7PX3NJlbMXEU5UGSzkd6oyMs=";
  };

  vendorHash = "sha256-k0jRlsFmBJNbfX3u2UQlnx/Z25KII8fYegU+Z77/EO0=";

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
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ garbas ];
    mainProgram = "agent-deck";
  };
}
