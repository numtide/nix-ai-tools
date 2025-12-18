{
  lib,
  python3,
  fetchPypi,
}:

python3.pkgs.buildPythonPackage rec {
  pname = "mistralai";
  version = "1.10.0";
  pyproject = true;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-yS6aXscFdXezJtR6SxwYb0JmC8y+lRZ/wlxob+ZYrSM=";
  };

  build-system = with python3.pkgs; [ poetry-core ];

  dependencies = with python3.pkgs; [
    eval-type-backport
    httpx
    invoke
    pydantic
    python-dateutil
    typing-inspection
    pyyaml
  ];

  pythonImportsCheck = [ "mistralai" ];

  meta = with lib; {
    description = "Python Client SDK for the Mistral AI API";
    homepage = "https://github.com/mistralai/client-python";
    license = licenses.asl20;
    sourceProvenance = with sourceTypes; [ fromSource ];
    platforms = platforms.all;
  };
}
