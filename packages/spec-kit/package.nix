{
  lib,
  python3,
  fetchFromGitHub,
}:

python3.pkgs.buildPythonApplication rec {
  pname = "spec-kit";
  version = "0.0.20";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "github";
    repo = "spec-kit";
    rev = "ea90d02c4149658def15dd37aa4358788de70012";
    hash = lib.fakeHash;
  };

  build-system = with python3.pkgs; [
    hatchling
  ];

  dependencies = with python3.pkgs; [
    typer
    rich
    httpx
    platformdirs
    readchar
    truststore
  ];

  pythonImportsCheck = [ "specify_cli" ];

  meta = {
    description = "Specify CLI, part of GitHub Spec Kit. A tool to bootstrap your projects for Spec-Driven Development (SDD)";
    homepage = "https://github.com/github/spec-kit";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    mainProgram = "specify";
  };
}
