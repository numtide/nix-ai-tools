{
  lib,
  python3,
  fetchFromGitHub,
}:

python3.pkgs.buildPythonApplication rec {
  pname = "skills-ref";
  version = "0.1.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "agentskills";
    repo = "agentskills";
    rev = "main";
    hash = "sha256-nZLgAd+ixQtWknKew5M9N1xr8Bo1xbTmPFSvxcYcgS4=";
  };

  sourceRoot = "source/skills-ref";

  build-system = with python3.pkgs; [
    hatchling
  ];

  dependencies = with python3.pkgs; [
    click
    strictyaml
  ];

  pythonImportsCheck = [ "skills_ref" ];

  passthru.category = "Utilities";

  meta = with lib; {
    description = "Reference library for Agent Skills";
    homepage = "https://github.com/agentskills/agentskills/tree/main/skills-ref";
    license = licenses.asl20;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with maintainers; [ ];
    mainProgram = "skills-ref";
    platforms = platforms.all;
  };
}
