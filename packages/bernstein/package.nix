{
  lib,
  flake,
  python3,
  fetchFromGitHub,
  fetchPypi,
  versionCheckHook,
  versionCheckHomeHook,
}:

let
  terminaltexteffects = python3.pkgs.buildPythonPackage rec {
    pname = "terminaltexteffects";
    version = "0.14.2";
    pyproject = true;

    src = fetchPypi {
      inherit pname version;
      hash = "sha256-ITyJnOS492Q9LQVorxROEnThHkST259bBDh70XwhdxQ=";
    };

    build-system = with python3.pkgs; [
      hatchling
    ];

    pythonImportsCheck = [ "terminaltexteffects" ];

    meta = with lib; {
      description = "Terminal visual effects engine";
      homepage = "https://github.com/ChrisBuilds/terminaltexteffects";
      license = licenses.mit;
      sourceProvenance = with sourceTypes; [ fromSource ];
      platforms = platforms.all;
    };
  };
in
python3.pkgs.buildPythonApplication rec {
  pname = "bernstein";
  version = "1.5.12";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "chernistry";
    repo = "bernstein";
    tag = "v${version}";
    hash = "sha256-pJzqrjYTONsAPmJqEzT7nmzYAh0pSfxWlkN2bsyQJLo=";
  };

  build-system = with python3.pkgs; [
    hatchling
  ];

  dependencies = with python3.pkgs; [
    click
    cryptography
    fastapi
    httpx
    mcp
    openai
    opentelemetry-api
    opentelemetry-exporter-otlp
    opentelemetry-sdk
    pillow
    pluggy
    prometheus-client
    pydantic-settings
    pyfiglet
    python-dotenv
    pyyaml
    rich
    setproctitle
    terminaltexteffects
    textual
    uvicorn
    watchdog
    websockets
  ];

  pythonRelaxDeps = [
    "cryptography"
    "openai"
    "opentelemetry-api"
    "opentelemetry-exporter-otlp"
    "opentelemetry-sdk"
    "pillow"
    "pydantic-settings"
    "python-dotenv"
  ];

  # bernstein re-invokes itself and uvicorn via ``sys.executable -m ...``
  # in subprocesses (server_launch.py, server_supervisor.py, adapters/*).
  # The Nix wrapper sets NIX_PYTHONPATH which is consumed and unset by
  # sitecustomize.py, so child interpreters lose access to the closure.
  # Export PYTHONPATH so subprocess spawns can resolve the runtime deps.
  makeWrapperArgs = [
    "--prefix"
    "PYTHONPATH"
    ":"
    "${placeholder "out"}/${python3.sitePackages}:${python3.pkgs.makePythonPath dependencies}"
  ];

  pythonImportsCheck = [ "bernstein" ];

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];
  versionCheckProgramArg = [ "--version" ];

  passthru.category = "AI Coding Agents";

  meta = with lib; {
    description = "Multi-agent orchestrator for CLI coding agents — spawn, coordinate, and manage parallel AI agents";
    homepage = "https://github.com/chernistry/bernstein";
    changelog = "https://github.com/chernistry/bernstein/releases/tag/v${version}";
    license = licenses.asl20;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ chernistry ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    mainProgram = "bernstein";
  };
}
