{
  lib,
  python3,
  fetchFromGitHub,
  textual-speedups,
}:

let
  python = python3.override {
    self = python;
    packageOverrides = _final: _prev: {
      # Inject textual-speedups into the Python package set
      inherit textual-speedups;
    };
  };
in
python.pkgs.buildPythonApplication rec {
  pname = "batrachian-toad";
  version = "0.5.5";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "batrachianai";
    repo = "toad";
    rev = "v${version}";
    hash = "sha256-78QFeygtvOe52EJa08jsZ5pM48clOTwG/PmDYuYmzSQ=";
  };

  build-system = with python.pkgs; [
    hatchling
  ];

  dependencies = with python.pkgs; [
    textual
    click
    gitpython
    tree-sitter
    httpx
    platformdirs
    rich
    typeguard
    xdg-base-dirs
    textual-serve
    textual-speedups
    packaging
    bashlex
    pathspec
  ];

  # Relax version constraint for hatchling in build-system
  pythonRelaxDeps = [
    "hatchling"
  ];

  # Remove exact version pinning from build-system
  postPatch = ''
    substituteInPlace pyproject.toml \
      --replace-fail 'requires = ["hatchling==1.28.0"]' 'requires = ["hatchling"]'

    # Fix TYPE_CHECKING import issues - add future annotations import
    sed -i '1i from __future__ import annotations' src/toad/app.py
  '';

  pythonImportsCheck = [ "toad" ];

  meta = with lib; {
    description = "A unified experience for AI in your terminal";
    homepage = "https://github.com/batrachianai/toad";
    license = licenses.agpl3Only;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with maintainers; [ ];
    mainProgram = "toad";
    platforms = platforms.all;
  };
}
