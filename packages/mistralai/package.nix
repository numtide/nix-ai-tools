{
  lib,
  python3,
  fetchPypi,
}:

python3.pkgs.buildPythonPackage rec {
  pname = "mistralai";
  version = "2.0.0";
  pyproject = true;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-rLeTelMRns5n9JeICdTPYw+/VLTf6FwO6ud4rECFD6s=";
  };

  build-system = with python3.pkgs; [ hatchling ];

  dependencies = with python3.pkgs; [
    eval-type-backport
    httpx
    opentelemetry-api
    opentelemetry-semantic-conventions
    pydantic
    python-dateutil
    typing-inspection
  ];

  # Relax version constraints for OpenTelemetry packages where nixpkgs versions are older:
  # - opentelemetry-semantic-conventions: requires >=0.60b1, nixpkgs has 0.55b0
  pythonRelaxDeps = [
    "opentelemetry-semantic-conventions"
  ];

  pythonImportsCheck = [ "mistralai" ];

  passthru.hideFromDocs = true;

  meta = with lib; {
    description = "Python Client SDK for the Mistral AI API";
    homepage = "https://github.com/mistralai/client-python";
    changelog = "https://github.com/mistralai/client-python/releases/tag/v${version}";
    license = licenses.asl20;
    sourceProvenance = with sourceTypes; [ fromSource ];
    platforms = platforms.all;
  };
}
