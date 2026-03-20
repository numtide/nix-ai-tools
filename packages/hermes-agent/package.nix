{
  lib,
  flake,
  python3,
  fetchFromGitHub,
  fetchpatch,
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
  version = "2026.3.17";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "NousResearch";
    repo = "hermes-agent";
    rev = "v${version}";
    hash = "sha256-x483+CKrY7r6NwTwb4iVVB3yyfioOwswfXSC5rfkiGI=";
  };

  patches = [
    # fix: add source files to wheel
    # https://github.com/NousResearch/hermes-agent/commit/cd46b1af04626f3baf85700e98f8510777ccfbbf
    # drop when > 2026.3.17 when https://github.com/NousResearch/hermes-agent/pull/2080 is merged
    (fetchpatch {
      url = "https://github.com/NousResearch/hermes-agent/commit/cd46b1af04626f3baf85700e98f8510777ccfbbf.patch";
      hash = "sha256-b6jw/YIUSeVKYXfd+BM+jD1UMnYClVEtlhKDNDoplTI=";
    })
  ];

  build-system = with python3.pkgs; [
    setuptools
  ];

  dependencies = with python3.pkgs; [
    # Core
    openai
    anthropic
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
    # Tools
    firecrawl-py
    fal-client
    # Text-to-speech
    edge-tts
    faster-whisper
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
