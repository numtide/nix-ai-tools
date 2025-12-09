{
  lib,
  python3,
  fetchFromGitHub,
  mistralai,
  agent-client-protocol,
}:

let
  python = python3.override {
    self = python;
    packageOverrides = _final: _prev: {
      # Inject local packages into the Python package set
      inherit mistralai agent-client-protocol;
    };
  };
in
python.pkgs.buildPythonApplication rec {
  pname = "mistral-vibe";
  version = "1.0.2";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "mistralai";
    repo = "mistral-vibe";
    rev = "v${version}";
    hash = "sha256-LPRxltovlBu2VNlzYTXIVIxsJ2E+sH/ah+Fs0HgUXfI=";
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
    tomli-w
    watchfiles
  ];

  # Relax version constraints - nixpkgs versions are slightly older but compatible
  pythonRelaxDeps = [
    "pydantic"
    "pydantic-settings"
    "watchfiles"
  ];

  pythonImportsCheck = [ "vibe" ];

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
