{
  lib,
  python3,
  fetchFromGitHub,
}:

python3.pkgs.buildPythonApplication rec {
  pname = "spec-kit";
  version = "0.0.92";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "github";
    repo = "spec-kit";
    rev = "v${version}";
    hash = "sha256-8PLtsEA3LvpXzEYluXsApIpQrC1yZyWHn0MxomJrSMc=";
  };

  build-system = with python3.pkgs; [
    hatchling
  ];

  dependencies = with python3.pkgs; [
    typer
    rich
    httpx
    socksio
    platformdirs
    readchar
    truststore
  ];

  pythonImportsCheck = [ "specify_cli" ];

  passthru.category = "Workflow & Project Management";

  meta = with lib; {
    description = "Specify CLI, part of GitHub Spec Kit. A tool to bootstrap your projects for Spec-Driven Development (SDD)";
    homepage = "https://github.com/github/spec-kit";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [ fromSource ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    mainProgram = "specify";
  };
}
