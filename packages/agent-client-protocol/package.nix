{
  lib,
  python3,
  fetchPypi,
}:

python3.pkgs.buildPythonPackage rec {
  pname = "agent-client-protocol";
  version = "0.6.3";
  pyproject = true;

  src = fetchPypi {
    pname = "agent_client_protocol";
    inherit version;
    hash = "sha256-6gGlHVtVhkxgZAFpTa1CnYPFvttHaAfYG4IIAx1s89g=";
  };

  build-system = with python3.pkgs; [ hatchling ];

  dependencies = with python3.pkgs; [
    pydantic
  ];

  pythonImportsCheck = [ "acp" ];

  meta = with lib; {
    description = "Agent Client Protocol - A protocol for AI agent communication";
    homepage = "https://github.com/anthropics/agent-client-protocol";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [ fromSource ];
    platforms = platforms.all;
  };
}
