{
  lib,
  python3,
  fetchPypi,
  rustPlatform,
  cargo,
  rustc,
  maturin,
}:

python3.pkgs.buildPythonPackage rec {
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
    homepage = "https://github.com/Textualize/textual-speedups";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with maintainers; [ ];
    platforms = platforms.all;
  };
}
