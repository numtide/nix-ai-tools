{
  lib,
  python3,
  fetchPypi,
}:

python3.pkgs.buildPythonPackage rec {
  pname = "agent-client-protocol";
  version = "0.9.0";
  pyproject = true;

  src = fetchPypi {
    pname = "agent_client_protocol";
    inherit version;
    hash = "sha256-90TEirmvDwtEUuWrVJjWG8q5fCbb59b+7F/TbeSb4ws=";
  };

  build-system = with python3.pkgs; [ pdm-backend ];

  dependencies = with python3.pkgs; [
    pydantic
  ];

  pythonImportsCheck = [ "acp" ];

  passthru.category = "ACP Ecosystem";

  meta = with lib; {
    description = "Agent Client Protocol - A protocol for AI agent communication";
    homepage = "https://github.com/agentclientprotocol/agent-client-protocol";
    changelog = "https://github.com/agentclientprotocol/agent-client-protocol/releases/tag/v${version}";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [ fromSource ];
    platforms = platforms.all;
  };
}
