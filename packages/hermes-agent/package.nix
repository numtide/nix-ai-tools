{
  lib,
  flake,
  python3,
  fetchFromGitHub,
  fetchPypi,
  versionCheckHook,
  versionCheckHomeHook,
  buildNpmPackage,
  fetchNpmDepsWithPackuments,
  npmConfigHook,
  nodejs,
  ripgrep,
  git,
  openssh,
  ffmpeg,
  agent-browser,
  playwright-driver,
  withMessagers ? true,
  withFull ? false,
  attachFullPassthru ? true,
}:

let
  pname = "hermes-agent";
  version = "2026.4.16";

  src = fetchFromGitHub {
    owner = "NousResearch";
    repo = "hermes-agent";
    rev = "v${version}";
    hash = "sha256-+Kltn1Ar0Ye4iBc6UVwvNPGI0uIgnCktl4Obh964/60=";
  };

  webSrc = builtins.path {
    name = "${pname}-web-source";
    path = src + "/web";
  };

  whatsappBridgeSrc = builtins.path {
    name = "${pname}-whatsapp-bridge-source";
    path = src + "/scripts/whatsapp-bridge";
  };

  mkSetuptoolsPackage =
    {
      pname,
      version,
      dependencies ? [ ],
      pythonImportsCheck ? [ ],
      relaxDeps ? [ ],
      pypiName ? pname,
      buildSystem ? with python3.pkgs; [ setuptools ],
      hash,
      description,
      homepage,
      license,
    }:
    python3.pkgs.buildPythonPackage {
      inherit
        pname
        version
        dependencies
        pythonImportsCheck
        ;
      pyproject = true;

      src = fetchPypi {
        pname = pypiName;
        inherit version hash;
      };

      build-system = buildSystem;
      pythonRelaxDeps = relaxDeps;

      meta = with lib; {
        inherit description homepage license;
        sourceProvenance = with sourceTypes; [ fromSource ];
        platforms = platforms.all;
      };
    };

  mkWheelPackage =
    {
      pname,
      version,
      dependencies ? [ ],
      pythonImportsCheck ? [ ],
      pypiName,
      hash,
      description,
      homepage,
      license,
    }:
    python3.pkgs.buildPythonPackage {
      inherit
        pname
        version
        dependencies
        pythonImportsCheck
        ;
      format = "wheel";

      src = fetchPypi {
        pname = pypiName;
        inherit version hash;
        format = "wheel";
        dist = "py3";
        python = "py3";
        abi = "none";
        platform = "any";
      };

      meta = with lib; {
        inherit description homepage license;
        sourceProvenance = with sourceTypes; [ binaryBytecode ];
        platforms = platforms.all;
      };
    };

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

  darabonba-core = mkWheelPackage {
    pname = "darabonba-core";
    pypiName = "darabonba_core";
    version = "1.0.5";
    hash = "sha256-Zxq428Ttwqj4gBPacWRoObuJFPElnvwGk1MkPvUuonw=";
    dependencies = with python3.pkgs; [
      aiohttp
      requests
      python3.pkgs."alibabacloud-tea"
    ];
    pythonImportsCheck = [ "darabonba.core" ];
    description = "Darabonba core runtime for Alibaba Cloud SDKs";
    homepage = "https://pypi.org/project/darabonba-core/";
    license = lib.licenses.asl20;
  };

  daytona-api-client = mkSetuptoolsPackage {
    pname = "daytona-api-client";
    pypiName = "daytona_api_client";
    version = "0.167.0";
    hash = "sha256-Yd4qDPlPr3dVxrvh+PnTX9Dm6UzQNGX/dntS5Irjdvo=";
    dependencies = with python3.pkgs; [
      urllib3
      python-dateutil
      pydantic
      typing-extensions
    ];
    pythonImportsCheck = [ "daytona_api_client" ];
    description = "Sync Python client for Daytona API";
    homepage = "https://pypi.org/project/daytona-api-client/";
    license = lib.licenses.asl20;
  };

  daytona-api-client-async = mkSetuptoolsPackage {
    pname = "daytona-api-client-async";
    pypiName = "daytona_api_client_async";
    version = "0.167.0";
    hash = "sha256-5j6z7dYRGydB1us1DtfJIQD9YUfEbeWkeW59/DAJhTw=";
    dependencies = with python3.pkgs; [
      urllib3
      python-dateutil
      aiohttp
      python3.pkgs."aiohttp-retry"
      pydantic
      typing-extensions
    ];
    pythonImportsCheck = [ "daytona_api_client_async" ];
    description = "Async Python client for Daytona API";
    homepage = "https://pypi.org/project/daytona-api-client-async/";
    license = lib.licenses.asl20;
  };

  daytona-toolbox-api-client = mkSetuptoolsPackage {
    pname = "daytona-toolbox-api-client";
    pypiName = "daytona_toolbox_api_client";
    version = "0.167.0";
    hash = "sha256-X/e0FBaEZyIewUv0+zi9qKRTezTb4A4SyO7j/67m+cM=";
    dependencies = with python3.pkgs; [
      urllib3
      python-dateutil
      pydantic
      typing-extensions
    ];
    pythonImportsCheck = [ "daytona_toolbox_api_client" ];
    description = "Sync Python client for Daytona toolbox API";
    homepage = "https://pypi.org/project/daytona-toolbox-api-client/";
    license = lib.licenses.asl20;
  };

  daytona-toolbox-api-client-async = mkSetuptoolsPackage {
    pname = "daytona-toolbox-api-client-async";
    pypiName = "daytona_toolbox_api_client_async";
    version = "0.167.0";
    hash = "sha256-xPmT4lQ5azPSNM8ATZclKZLLIP439fZj1GQK9r73quw=";
    dependencies = with python3.pkgs; [
      urllib3
      python-dateutil
      aiohttp
      python3.pkgs."aiohttp-retry"
      pydantic
      typing-extensions
    ];
    pythonImportsCheck = [ "daytona_toolbox_api_client_async" ];
    description = "Async Python client for Daytona toolbox API";
    homepage = "https://pypi.org/project/daytona-toolbox-api-client-async/";
    license = lib.licenses.asl20;
  };

  daytona = mkSetuptoolsPackage {
    pname = "daytona";
    version = "0.167.0";
    hash = "sha256-t0Zz1e1NWtFgh4gn1J/RWh9Oeu3DKXZxwqBdr7a+Ux0=";
    dependencies =
      with python3.pkgs;
      [
        python-dotenv
        pydantic
        deprecated
        httpx
        aiofiles
        toml
        obstore
        websockets
        python3.pkgs."python-multipart"
        python3.pkgs."opentelemetry-api"
        python3.pkgs."opentelemetry-sdk"
        python3.pkgs."opentelemetry-exporter-otlp-proto-http"
        python3.pkgs."opentelemetry-instrumentation-aiohttp-client"
        urllib3
      ]
      ++ [
        daytona-api-client
        daytona-api-client-async
        daytona-toolbox-api-client
        daytona-toolbox-api-client-async
      ];
    buildSystem = with python3.pkgs; [ poetry-core ];
    relaxDeps = [
      "aiofiles"
      "obstore"
      "opentelemetry-instrumentation-aiohttp-client"
      "websockets"
    ];
    pythonImportsCheck = [ "daytona" ];
    description = "Python SDK for Daytona sandboxes";
    homepage = "https://github.com/daytonaio/daytona-python-sdk";
    license = lib.licenses.asl20;
  };

  honcho-ai = mkSetuptoolsPackage {
    pname = "honcho-ai";
    pypiName = "honcho_ai";
    version = "2.1.1";
    hash = "sha256-0nPYbOPnNhdVwISw3cRBYNScWcU4snjfYG5kN72JOmE=";
    dependencies = with python3.pkgs; [
      httpx
      pydantic
      typing-extensions
    ];
    pythonImportsCheck = [ "honcho" ];
    description = "Honcho AI Python client";
    homepage = "https://github.com/plastic-labs/honcho";
    license = lib.licenses.asl20;
  };

  dingtalk-stream = mkWheelPackage {
    pname = "dingtalk-stream";
    pypiName = "dingtalk_stream";
    version = "0.24.3";
    hash = "sha256-IWBANlaYWWKHi/YM31rfQWGfIQZzSOBvB6fH7r9ZQ60=";
    dependencies = with python3.pkgs; [
      aiohttp
      requests
      websockets
    ];
    pythonImportsCheck = [ "dingtalk_stream" ];
    description = "DingTalk stream mode SDK";
    homepage = "https://pypi.org/project/dingtalk-stream/";
    license = lib.licenses.mit;
  };

  alibabacloud-gateway-dingtalk = mkSetuptoolsPackage {
    pname = "alibabacloud-gateway-dingtalk";
    pypiName = "alibabacloud_gateway_dingtalk";
    version = "1.0.2";
    hash = "sha256-rOqLCx0R4DlJE/CwiZ3dGcC/zqtxYGBEm1f8wlDOswA=";
    dependencies = with python3.pkgs; [
      python3.pkgs."alibabacloud-gateway-spi"
      python3.pkgs."alibabacloud-tea-util"
    ];
    pythonImportsCheck = [ "alibabacloud_gateway_dingtalk" ];
    description = "Alibaba Cloud DingTalk gateway bindings";
    homepage = "https://pypi.org/project/alibabacloud-gateway-dingtalk/";
    license = lib.licenses.asl20;
  };

  alibabacloud-tea-openapi = mkSetuptoolsPackage {
    pname = "alibabacloud-tea-openapi";
    pypiName = "alibabacloud_tea_openapi";
    version = "0.4.4";
    hash = "sha256-GwkXvAPNSUF9pklF6ScxcW1T4uuHB7I19U5Ft0cyIc4=";
    dependencies =
      with python3.pkgs;
      [
        python3.pkgs."alibabacloud-credentials"
        python3.pkgs."alibabacloud-gateway-spi"
        python3.pkgs."alibabacloud-tea-util"
        cryptography
      ]
      ++ [ darabonba-core ];
    pythonImportsCheck = [ "alibabacloud_tea_openapi" ];
    description = "Alibaba Cloud Tea OpenAPI runtime";
    homepage = "https://pypi.org/project/alibabacloud-tea-openapi/";
    license = lib.licenses.asl20;
  };

  alibabacloud-dingtalk = mkSetuptoolsPackage {
    pname = "alibabacloud-dingtalk";
    pypiName = "alibabacloud_dingtalk";
    version = "2.2.43";
    hash = "sha256-kblUscnAHIF06SbfqsZk9I5iYssxiC81z1deMZqafIc=";
    dependencies =
      with python3.pkgs;
      [
        python3.pkgs."alibabacloud-endpoint-util"
        python3.pkgs."alibabacloud-gateway-spi"
        python3.pkgs."alibabacloud-openapi-util"
        python3.pkgs."alibabacloud-tea-util"
      ]
      ++ [
        alibabacloud-gateway-dingtalk
        alibabacloud-tea-openapi
      ];
    pythonImportsCheck = [ "alibabacloud_dingtalk" ];
    description = "Alibaba Cloud DingTalk Python SDK";
    homepage = "https://pypi.org/project/alibabacloud-dingtalk/";
    license = lib.licenses.asl20;
  };

  lark-oapi = mkWheelPackage {
    pname = "lark-oapi";
    pypiName = "lark_oapi";
    version = "1.5.3";
    hash = "sha256-/aazK7ONIba9qulJecYAuUx8Uh6YWtreY6VOSz4gzDY=";
    dependencies = with python3.pkgs; [
      requests
      requests-toolbelt
      pycryptodome
      websockets
      httpx
    ];
    pythonImportsCheck = [ "lark_oapi" ];
    description = "Feishu/Lark OpenAPI SDK";
    homepage = "https://pypi.org/project/lark-oapi/";
    license = lib.licenses.asl20;
  };

  rootNodeModules = buildNpmPackage {
    pname = "${pname}-node-modules";
    inherit src version;
    sourceRoot = src.name;
    npmDepsHash = "sha256-6RAksR7kN+l4s8331Vf7+Ivs7nS6ovJjR4ekjaeE5iA=";
    dontNpmBuild = true;

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r node_modules package.json package-lock.json $out/
      runHook postInstall
    '';
  };

  whatsappBridge = buildNpmPackage (finalAttrs: {
    inherit npmConfigHook;
    pname = "${pname}-whatsapp-bridge";
    src = whatsappBridgeSrc;
    inherit version;

    npmDeps = fetchNpmDepsWithPackuments {
      inherit (finalAttrs) src;
      name = "${finalAttrs.pname}-${finalAttrs.version}-npm-deps";
      hash = "sha256-LASR5tasBtpWBU7Q/CEzURr0VWu5KnDgv84fT4KamsE=";
      fetcherVersion = 2;
      forceGitDeps = true;
    };

    forceGitDeps = true;
    makeCacheWritable = true;
    dontNpmBuild = true;

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r allowlist.js bridge.js node_modules package.json package-lock.json $out/
      runHook postInstall
    '';
  });

  mkHermes =
    {
      withMessagers,
      withFull,
    }:
    let
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
          # Web dashboard
          fastapi
          uvicorn
        ]
        ++ lib.optionals withMessagers [
          qrcode
          # Telegram
          python3.pkgs."python-telegram-bot"
          aiohttp
          # Matrix
          mautrix
          markdown
          aiosqlite
          asyncpg
          # Discord
          discordpy
          # Slack
          python3.pkgs."slack-bolt"
          python3.pkgs."slack-sdk"
        ]
        ++ lib.optionals withFull [
          # Upstream base extras not present in the default package.
          socksio
          cryptography
          tornado
          # Full upstream .[all] extras.
          modal
          daytona
          debugpy
          pytest
          pytest-asyncio
          pytest-xdist
          elevenlabs
          ptyprocess
          honcho-ai
          python3.pkgs."agent-client-protocol"
          mistralai
          boto3
          sounddevice
          numpy
          dingtalk-stream
          alibabacloud-dingtalk
          lark-oapi
          pynacl
        ];
    in
    python3.pkgs.buildPythonApplication rec {
      inherit
        pname
        version
        src
        dependencies
        ;
      pyproject = true;

      build-system = with python3.pkgs; [
        setuptools
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

      makeWrapperArgs = lib.optionals withFull [
        "--prefix"
        "PATH"
        ":"
        (lib.makeBinPath [
          nodejs
          ripgrep
          git
          openssh
          ffmpeg
          agent-browser
        ])
        "--set"
        "PLAYWRIGHT_BROWSERS_PATH"
        "${playwright-driver.browsers}"
        "--set"
        "PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS"
        "true"
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

      postInstall = lib.optionalString withFull ''
        site_packages="$out/${python3.sitePackages}"

        cp -r ${rootNodeModules}/node_modules "$site_packages/"
        cp ${rootNodeModules}/package.json ${rootNodeModules}/package-lock.json "$site_packages/"

        mkdir -p "$site_packages/scripts/whatsapp-bridge"
        cp -r ${whatsappBridge}/. "$site_packages/scripts/whatsapp-bridge/"
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
        src = webSrc;
        inherit version;
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
      }
      // lib.optionalAttrs attachFullPassthru {
        full = import ./full.nix {
          inherit
            lib
            flake
            python3
            fetchFromGitHub
            fetchPypi
            versionCheckHook
            versionCheckHomeHook
            buildNpmPackage
            fetchNpmDepsWithPackuments
            npmConfigHook
            nodejs
            ripgrep
            git
            openssh
            ffmpeg
            agent-browser
            playwright-driver
            ;
        };
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
    };
in
mkHermes {
  inherit withMessagers withFull;
}
