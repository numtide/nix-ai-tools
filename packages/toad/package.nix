{
  lib,
  python3,
  fetchFromGitHub,
}:

python3.pkgs.buildPythonApplication rec {
  pname = "batrachian-toad";
  version = "0.5.5";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "batrachianai";
    repo = "toad";
    rev = "v${version}";
    hash = "sha256-78QFeygtvOe52EJa08jsZ5pM48clOTwG/PmDYuYmzSQ=";
  };

  build-system = with python3.pkgs; [
    hatchling
  ];

  dependencies = with python3.pkgs; [
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
    packaging
    bashlex
    pathspec
  ];

  # Relax version constraints for better maintainability
  pythonRelaxDeps = true;

  # Remove optional dependencies not available in nixpkgs
  pythonRemoveDeps = [
    "textual-speedups"
  ];

  # Remove exact version pinning from build-system
  postPatch = ''
    substituteInPlace pyproject.toml \
      --replace-fail 'requires = ["hatchling==1.28.0"]' 'requires = ["hatchling"]' \
      --replace-fail '"textual-speedups==0.2.1",' ""

    # Fix TYPE_CHECKING import issues in app.py - quote forward references
    substituteInPlace src/toad/app.py \
      --replace-fail "def get_settings_screen() -> SettingsScreen:" 'def get_settings_screen() -> "SettingsScreen":' \
      --replace-fail "def get_store_screen() -> StoreScreen:" 'def get_store_screen() -> "StoreScreen":' \
      --replace-fail "def get_default_screen(self) -> MainScreen:" 'def get_default_screen(self) -> "MainScreen":'
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
