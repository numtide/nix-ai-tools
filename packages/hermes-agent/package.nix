{
  lib,
  stdenv,
  flake,
  python3,
  fetchFromGitHub,
  fetchPypi,
  versionCheckHook,
  versionCheckHomeHook,
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
  version = "2026.4.23";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "NousResearch";
    repo = "hermes-agent";
    rev = "v${version}";
    hash = "sha256-cJEYjf8xV4vDw9xRBh9SHMhamj5wNjEhmMO5O3s5lag=";
  };

  build-system = with python3.pkgs; [
    setuptools
  ];

  dependencies =
    with python3.pkgs;
    [
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
      # MCP
      mcp
      # Tools
      exa-py
      firecrawl-py
      parallel-web
      fal-client
      # Text-to-speech
      edge-tts
      # Skills Hub
      pyjwt
    ]
    # faster-whisper -> av currently SIGKILLs during pythonImportsCheck on
    # darwin in nixpkgs-unstable; the voice pipeline is optional, so only
    # ship it where it builds.
    ++ lib.optionals stdenv.hostPlatform.isLinux [ faster-whisper ]
    ++ optional-dependencies.gateway
    ++ optional-dependencies.misc;

  # Upstream ships most integrations as setuptools extras and degrades
  # "gracefully" at runtime by logging a warning and refusing to start the
  # adapter (see #4175 for the slack-bolt case). In a Nix closure the user
  # cannot `pip install hermes-agent[slack]`, so pull in every extra that is
  # already packaged in nixpkgs. Extras whose deps are not yet in nixpkgs
  # (honcho, daytona, dingtalk, feishu) are intentionally omitted.
  optional-dependencies = with python3.pkgs; {
    # Everything the `hermes gateway` command can use.
    gateway = [
      # [messaging] / [slack]
      slack-bolt
      slack-sdk
      python-telegram-bot
      discordpy
      aiohttp # also covers [homeassistant] and [sms]
      # [cron]
      croniter
      # [web]
      fastapi
      uvicorn
    ]
    ++ lib.optionals stdenv.hostPlatform.isLinux [
      # [matrix] — upstream gates this on linux because python-olm is
      # broken on modern macOS toolchains.
      mautrix
      markdown
      aiosqlite
      asyncpg
    ];
    # Non-gateway extras kept separate so the test closure can stay slim if
    # someone later wants `hermes-agent.override { withExtras = false; }`.
    misc = [
      # [cli]
      simple-term-menu
      # [pty]
      ptyprocess
      # [acp]
      agent-client-protocol
      # [voice] (faster-whisper already in core deps above)
      sounddevice
      numpy
      # [tts-premium]
      elevenlabs
      # [mistral]
      mistralai
      # [bedrock]
      boto3
      # [modal]
      modal
    ];
  };

  pythonRelaxDeps = [
    "tenacity"
    "requests"
    "pydantic"
    "firecrawl-py"
    "pyjwt"
  ];

  pythonImportsCheck = [
    "hermes_cli"
    # Regression guard for #4175: these adapters swallow ImportError and only
    # warn at runtime, so assert the underlying libraries import cleanly.
    "slack_bolt"
    "discord"
    "telegram.ext"
    "croniter"
  ];

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
