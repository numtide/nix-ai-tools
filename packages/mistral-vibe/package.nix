{
  lib,
  python3,
  fetchFromGitHub,
  fetchPypi,
  callPackage,
  rustPlatform,
  cargo,
  rustc,
  maturin,
  versionCheckHook,
  versionCheckHomeHook,
}:

let
  textual-speedups = python3.pkgs.buildPythonPackage rec {
    pname = "textual-speedups";
    version = "0.2.1";
    pyproject = true;

    src = fetchPypi {
      pname = "textual_speedups";
      inherit version;
      hash = "sha256-cs8Pe97t4BU2e1m3C89yS6LDCAqGQevF65SzatFTaCQ=";
    };

    cargoDeps = rustPlatform.fetchCargoVendor {
      inherit src;
      name = "${pname}-${version}";
      hash = "sha256-Bz4ocEziOlOX4z5F9EDry99YofeGyxL/6OTIf/WEgK4=";
    };

    nativeBuildInputs = [
      rustPlatform.cargoSetupHook
      rustPlatform.maturinBuildHook
      cargo
      rustc
      maturin
    ];

    pythonImportsCheck = [ "textual_speedups" ];

    meta = with lib; {
      description = "Optional Rust speedups for Textual TUI framework";
      homepage = "https://github.com/willmcgugan/textual-speedups";
      license = licenses.mit;
      sourceProvenance = with sourceTypes; [ fromSource ];
      platforms = platforms.all;
    };
  };

  tree-sitter-bash = python3.pkgs.buildPythonPackage rec {
    pname = "tree-sitter-bash";
    version = "0.25.1";
    pyproject = true;

    src = fetchPypi {
      pname = "tree_sitter_bash";
      inherit version;
      hash = "sha256-v8C9qne8HobjxmUuWm4UDEDAoWuEGFwrY6182Am4jxQ=";
    };

    build-system = with python3.pkgs; [
      setuptools
    ];

    pythonImportsCheck = [ "tree_sitter_bash" ];

    meta = with lib; {
      description = "Bash grammar for tree-sitter";
      homepage = "https://github.com/tree-sitter/tree-sitter-bash";
      license = licenses.mit;
      sourceProvenance = with sourceTypes; [ fromSource ];
      platforms = platforms.all;
    };
  };

  # mistral-vibe >=2.6 requires opentelemetry-semantic-conventions>=0.60b1 for
  # GEN_AI_PROVIDER_NAME (issue #3668). nixpkgs ships 0.55b0. The otel packages
  # are versioned in lockstep from a monorepo and all inherit src from
  # opentelemetry-api, so bumping that one source bumps the whole stack.
  otelVersion = "1.40.0";
  otelContribVersion = "0.61b0";
  otelSrc = fetchFromGitHub {
    owner = "open-telemetry";
    repo = "opentelemetry-python";
    tag = "v${otelVersion}";
    hash = "sha256-1KVy9s+zjlB4w7E45PMCWRxPus24bgBmmM3k2R9d+Jg=";
  };
  otelContribSrc = fetchFromGitHub {
    owner = "open-telemetry";
    repo = "opentelemetry-python-contrib";
    tag = "v${otelContribVersion}";
    hash = "sha256-DT13gcYPNYXBPnf622WsA16C+7sabJfOshDquHn06Ok=";
  };

  python = python3.override {
    self = python;
    packageOverrides = _pyfinal: pyprev: {
      inherit textual-speedups tree-sitter-bash;

      # Build mistralai/acp inside this set so they link against the
      # overridden opentelemetry packages rather than stock python3.pkgs.
      # Otherwise the prebuilt ones drag old otel into the closure and
      # pythonRuntimeDepsCheck fails (or worse, succeeds and crashes at runtime).
      mistralai = callPackage ./mistralai.nix { python3 = python; };
      agent-client-protocol = callPackage ./agent-client-protocol.nix { python3 = python; };

      opentelemetry-api = pyprev.opentelemetry-api.overridePythonAttrs (_: {
        version = otelVersion;
        src = otelSrc;
        sourceRoot = "${otelSrc.name}/opentelemetry-api";
      });

      # 1.40.0 added timing-sensitive tests that flake on loaded builders
      # (assertions like `after - before < 0.2` fail by milliseconds on darwin).
      opentelemetry-exporter-otlp-proto-http =
        pyprev.opentelemetry-exporter-otlp-proto-http.overridePythonAttrs
          (old: {
            disabledTests = (old.disabledTests or [ ]) ++ [
              "test_retry_timeout"
              "test_shutdown_interrupts_retry_backoff"
            ];
          });

      opentelemetry-instrumentation = pyprev.opentelemetry-instrumentation.overridePythonAttrs (_: {
        version = otelContribVersion;
        src = otelContribSrc;
        sourceRoot = "${otelContribSrc.name}/opentelemetry-instrumentation";
      });

      # In nixpkgs this inherits version from opentelemetry-instrumentation,
      # but overridePythonAttrs doesn't re-evaluate that reference, so set it
      # explicitly to keep the dist-info version in sync with src.
      opentelemetry-semantic-conventions =
        pyprev.opentelemetry-semantic-conventions.overridePythonAttrs
          (_: {
            version = otelContribVersion;
          });
    };
  };
in
python.pkgs.buildPythonApplication rec {
  pname = "mistral-vibe";
  version = "2.7.4";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "mistralai";
    repo = "mistral-vibe";
    rev = "v${version}";
    hash = "sha256-SPn6YaGmEt2r9Fm3Eagubqw0Q2U5bSvNUY1qo2XfVlE=";
  };

  build-system = with python.pkgs; [
    hatchling
    hatch-vcs
  ];

  dependencies = with python.pkgs; [
    agent-client-protocol
    anyio
    cachetools
    cryptography
    gitpython
    giturlparse
    google-auth
    httpx
    keyring
    markdownify
    mcp
    mistralai
    opentelemetry-api
    opentelemetry-exporter-otlp-proto-http
    opentelemetry-sdk
    opentelemetry-semantic-conventions
    packaging
    pexpect
    pydantic
    pydantic-settings
    pyperclip
    python-dotenv
    pyyaml
    requests
    rich
    sounddevice
    textual
    textual-speedups
    tomli-w
    tree-sitter
    tree-sitter-bash
    watchfiles
    websockets
    zstandard
  ];

  # Relax version constraints - nixpkgs versions are slightly older but compatible.
  # NOTE: do NOT relax opentelemetry-* here; those constraints encode real API
  # requirements (see issue #3668) and are satisfied by the overrides above.
  pythonRelaxDeps = [
    "agent-client-protocol"
    "cryptography"
    "gitpython"
    "giturlparse"
    "keyring"
    "mistralai"
    "pydantic"
    "pydantic-settings"
    "pyyaml"
    "watchfiles"
    "zstandard"
  ];

  pythonImportsCheck = [ "vibe" ];

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];
  versionCheckProgramArg = [ "--version" ];

  passthru.category = "AI Coding Agents";

  meta = with lib; {
    description = "Minimal CLI coding agent by Mistral AI - open-source command-line coding assistant powered by Devstral";
    homepage = "https://github.com/mistralai/mistral-vibe";
    changelog = "https://github.com/mistralai/mistral-vibe/releases/tag/v${version}";
    license = licenses.asl20;
    sourceProvenance = with sourceTypes; [ fromSource ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    mainProgram = "vibe";
  };
}
