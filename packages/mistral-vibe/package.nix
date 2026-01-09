{
  lib,
  stdenv,
  python3,
  fetchFromGitHub,
  fetchPypi,
  mistralai,
  agent-client-protocol,
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

  python = python3.override {
    self = python;
    packageOverrides = _final: _prev: {
      # Inject local packages into the Python package set
      inherit mistralai agent-client-protocol textual-speedups;
      mcp = _prev.mcp.overrideAttrs (old: rec {
        version = "1.25.0";
        name = "${old.pname}-${version}";
        src = fetchFromGitHub {
          owner = "modelcontextprotocol";
          repo = "python-sdk";
          tag = "v${version}";
          hash = "sha256-fSQCvKaNMeCzguM2tcTJJlAeZQmzSJmbfEK35D8pQcs=";
        };
        postPatch = lib.optionalString stdenv.buildPlatform.isDarwin ''
          # time.sleep(0.1) feels a bit optimistic and it has been flaky whilst
          # testing this on macOS under load.
          substituteInPlace tests/client/test_stdio.py \
            --replace-fail "time.sleep(0.1)" "time.sleep(1)"
        '';
      });
    };
  };
in
python.pkgs.buildPythonApplication rec {
  pname = "mistral-vibe";
  version = "1.3.4";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "mistralai";
    repo = "mistral-vibe";
    rev = "v${version}";
    hash = "sha256-74sMmlhEgRHHwuBF6P57rfVuDQIRCngP3y1SNv/wZJQ=";
  };

  build-system = with python.pkgs; [
    hatchling
    hatch-vcs
  ];

  dependencies = with python.pkgs; [
    agent-client-protocol
    aiofiles
    httpx
    mcp
    mistralai
    packaging
    pexpect
    pydantic
    pydantic-settings
    pyperclip
    pytest-xdist
    python-dotenv
    rich
    textual
    textual-speedups
    tomli-w
    watchfiles
  ];

  # Relax version constraints - nixpkgs versions are slightly older but compatible
  pythonRelaxDeps = [
    "agent-client-protocol"
    "mistralai"
    "pydantic"
    "pydantic-settings"
    "watchfiles"
  ];

  pythonImportsCheck = [ "vibe" ];

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];
  versionCheckProgramArg = [ "--version" ];

  meta = with lib; {
    description = "Minimal CLI coding agent by Mistral AI - open-source command-line coding assistant powered by Devstral";
    homepage = "https://github.com/mistralai/mistral-vibe";
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
