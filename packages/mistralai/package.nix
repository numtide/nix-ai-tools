{
  lib,
  python3,
  fetchPypi,
}:

python3.pkgs.buildPythonPackage rec {
  pname = "mistralai";
  version = "1.12.2";
  pyproject = true;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-LvfFhAUuCmLsf+/bmkn1j0pox4tPhpT2fR8rEVPG/Tk=";
  };

  build-system = with python3.pkgs; [ hatchling ];

  dependencies = with python3.pkgs; [
    eval-type-backport
    httpx
    invoke
    opentelemetry-api
    opentelemetry-exporter-otlp-proto-http
    opentelemetry-sdk
    opentelemetry-semantic-conventions
    pydantic
    python-dateutil
    typing-inspection
    pyyaml
  ];

  # Relax version constraints for OpenTelemetry packages where nixpkgs versions are older:
  # - opentelemetry-exporter-otlp-proto-http: requires >=1.37.0, nixpkgs has 1.34.0
  # - opentelemetry-semantic-conventions: requires >=0.59b0, nixpkgs has 0.55b0
  pythonRelaxDeps = [
    "opentelemetry-exporter-otlp-proto-http"
    "opentelemetry-semantic-conventions"
  ];

  pythonImportsCheck = [ "mistralai" ];

  passthru.hideFromDocs = true;

  meta = with lib; {
    description = "Python Client SDK for the Mistral AI API";
    homepage = "https://github.com/mistralai/client-python";
    license = licenses.asl20;
    sourceProvenance = with sourceTypes; [ fromSource ];
    platforms = platforms.all;
  };
}
