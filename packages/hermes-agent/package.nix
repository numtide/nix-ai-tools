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
  fal-client = python3.pkgs.buildPythonPackage rec {
    pname = "fal-client";
    version = "0.13.1";
    pyproject = true;

    src = fetchPypi {
      pname = "fal_client";
      inherit version;
      hash = "sha256-nhwH0KYbRSqP+0jBmd5fJUPXVG8SMPYxI3BEMSfF6Tc=";
    };

    build-system = with python3.pkgs; [
      setuptools
      setuptools-scm
    ];

    dependencies = with python3.pkgs; [
      httpx
      httpx-sse
      msgpack
      websockets
    ];

    pythonImportsCheck = [ "fal_client" ];

    meta = with lib; {
      description = "Python client for fal.ai";
      homepage = "https://github.com/fal-ai/fal";
      license = licenses.asl20;
      sourceProvenance = with sourceTypes; [ fromSource ];
      platforms = platforms.all;
    };
  };
in
python3.pkgs.buildPythonApplication rec {
  pname = "hermes-agent";
  version = "2026.3.12";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "NousResearch";
    repo = "hermes-agent";
    rev = "v${version}";
    hash = "sha256-zOQm9cVjtwpDteIjjQsWn3SfCfw9tobtoAPU65rLYWA=";
  };

  postPatch = ''
    # The upstream pyproject.toml is incomplete for non-editable installs:
    # - "agent" package is missing from packages.find.include
    # - "hermes_state" and "hermes_time" modules are missing from py-modules
    substituteInPlace pyproject.toml \
      --replace-fail \
        'include = ["tools", "hermes_cli", "gateway", "cron", "honcho_integration"]' \
        'include = ["tools", "tools.*", "hermes_cli", "hermes_cli.*", "gateway", "gateway.*", "cron", "cron.*", "honcho_integration", "honcho_integration.*", "agent", "agent.*"]' \
      --replace-fail \
        'py-modules = ["run_agent", "model_tools", "toolsets", "batch_runner", "trajectory_compressor", "toolset_distributions", "cli", "hermes_constants"]' \
        'py-modules = ["run_agent", "model_tools", "toolsets", "batch_runner", "trajectory_compressor", "toolset_distributions", "cli", "hermes_constants", "hermes_state", "hermes_time"]'
  '';

  build-system = with python3.pkgs; [
    setuptools
  ];

  dependencies = with python3.pkgs; [
    # Core
    openai
    python-dotenv
    fire
    httpx
    rich
    tenacity
    pyyaml
    requests
    jinja2
    pydantic
    # Interactive CLI
    prompt-toolkit
    simple-term-menu
    # Tools
    firecrawl-py
    fal-client
    # Text-to-speech
    edge-tts
    # mini-swe-agent deps
    litellm
    typer
    platformdirs
    # Skills Hub
    pyjwt
  ];

  pythonRelaxDeps = [
    "litellm"
    "pydantic"
  ];

  pythonImportsCheck = [ "hermes_cli" ];

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];
  versionCheckProgramArg = [ "--version" ];

  passthru.category = "AI Assistants";

  meta = with lib; {
    description = "Self-improving AI agent by Nous Research — creates skills from experience and runs anywhere";
    homepage = "https://hermes-agent.nousresearch.com/";
    changelog = "https://github.com/NousResearch/hermes-agent/releases/tag/v${version}";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [ fromSource ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    maintainers = with flake.lib.maintainers; [ aliez-ren ];
    mainProgram = "hermes";
  };
}
