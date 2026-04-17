{
  lib,
  flake,
  python3,
  fetchFromGitHub,
  fetchPypi,
  versionCheckHook,
  versionCheckHomeHook,
  buildNpmPackage,
  withMessagers ? true,
}:

let
  exa-py = python3.pkgs.buildPythonPackage rec {
    pname = "exa-py";
    version = "2.10.2";
    pyproject = true;

    src = fetchPypi {
      pname = "exa_py";
      inherit version;
      hash = "sha256-94HzCxmfEQIzM4RyitrmS7Faa7yr+pfpH9cF+QrP/EU=";
    };

    build-system = with python3.pkgs; [
      poetry-core
    ];

    dependencies = with python3.pkgs; [
      httpcore
      httpx
      openai
      pydantic
      python-dotenv
      requests
      typing-extensions
    ];

    pythonImportsCheck = [ "exa_py" ];

    meta = with lib; {
      description = "Python SDK for Exa API";
      homepage = "https://github.com/exa-labs/exa-py";
      license = licenses.mit;
      sourceProvenance = with sourceTypes; [ fromSource ];
      platforms = platforms.all;
    };
  };

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

  parallel-web = python3.pkgs.buildPythonPackage rec {
    pname = "parallel-web";
    version = "0.4.2";
    pyproject = true;

    src = fetchPypi {
      pname = "parallel_web";
      inherit version;
      hash = "sha256-WZtajzh9w1x9yMgeNy6t9pWKQKys6li/Fw38ZjwAPac=";
    };

    build-system = with python3.pkgs; [
      hatchling
      hatch-fancy-pypi-readme
    ];

    # Upstream pins hatchling==1.26.3 in build-system.requires; any recent
    # hatchling works. pythonRelaxDeps only rewrites runtime metadata, so
    # skip the pypa-build dependency check instead of patching pyproject.toml.
    pypaBuildFlags = [ "--skip-dependency-check" ];

    dependencies = with python3.pkgs; [
      anyio
      distro
      httpx
      pydantic
      sniffio
      typing-extensions
    ];

    pythonImportsCheck = [ "parallel" ];

    meta = with lib; {
      description = "Python SDK for Parallel Web API";
      homepage = "https://github.com/parallel-web/parallel-sdk-python";
      license = licenses.asl20;
      sourceProvenance = with sourceTypes; [ fromSource ];
      platforms = platforms.all;
    };
  };
in
python3.pkgs.buildPythonApplication rec {
  pname = "hermes-agent";
  version = "2026.4.16";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "NousResearch";
    repo = "hermes-agent";
    rev = "v${version}";
    hash = "sha256-+Kltn1Ar0Ye4iBc6UVwvNPGI0uIgnCktl4Obh964/60=";
  };

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
    simple-term-menu
    # MCP
    mcp
    # Tools
    exa-py
    firecrawl-py
    parallel-web
    fal-client
    croniter
    # Text-to-speech
    edge-tts
    faster-whisper
    # Skills Hub
    pyjwt
    # web dashboard
    fastapi
    uvicorn
  ] ++ lib.optionals withMessagers [
    qrcode
    # Telegram
    python-telegram-bot
    aiohttp
    # Matrix
    mautrix
    markdown
    aiosqlite
    asyncpg
    # Discord
    discordpy
    # Slack
    slack-bolt
    slack-sdk
  ];

  pythonRelaxDeps = [
    "tenacity"
    "requests"
    "pydantic"
    "firecrawl-py"
    "pyjwt"
    "python-telegram-bot"
    "mautrix"
  ];

  postPatch = ''
    substituteInPlace hermes_cli/gateway.py \
      --replace-fail 'python_path = get_python_path()' 'hermes_cli = get_hermes_cli_path()' \
      --replace-fail 'ExecStart={python_path} -m hermes_cli.main{f" {profile_arg}" if profile_arg else ""} gateway run --replace' 'ExecStart={hermes_cli}{f" {profile_arg}" if profile_arg else ""} gateway run --replace'
  '';

  preBuild = ''
    mkdir -p hermes_cli
    cp -r ${frontend}/. hermes_cli/web_dist
  '';

  pythonImportsCheck = [ "hermes_cli" ];

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];
  versionCheckProgramArg = [ "--version" ];

  frontend = buildNpmPackage {
    pname = "hermes-agent-web";
    inherit src version;
    sourceRoot = "${src.name}/web";
    npmDepsHash = "sha256-Y0pOzdFG8BLjfvCLmsvqYpjxFjAQabXp1i7X9W/cCU4=";

    postPatch = ''
      substituteInPlace vite.config.ts \
        --replace-fail 'outDir: "../hermes_cli/web_dist",' 'outDir: "dist",'
    '';

    installPhase = ''
      runHook preInstall
      cp -r dist $out
      runHook postInstall
    '';
  };
 
  passthru = {
    inherit frontend;
    category = "AI Assistants";
  };

  meta = with lib; {
    description = "Self-improving AI agent by Nous Research — creates skills from experience and runs anywhere";
    homepage = "https://hermes-agent.nousresearch.com/";
    changelog = "https://github.com/NousResearch/hermes-agent/releases/tag/v${version}";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [ fromSource ];
    # x86_64-darwin dropped: arrow-cpp (via litellm -> tokenizers -> datasets
    # -> pyarrow) is marked broken there, and nixpkgs 26.05 is the last
    # release supporting the platform anyway.
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "aarch64-darwin"
    ];
    maintainers = with flake.lib.maintainers; [ aliez-ren ];
    mainProgram = "hermes";
  };
}
