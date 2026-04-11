{
  lib,
  flake,
  rustPlatform,
  fetchCrate,
}:

rustPlatform.buildRustPackage rec {
  pname = "toon-format";
  version = "0.4.5";

  src = fetchCrate {
    inherit pname version;
    hash = "sha256-DA3X3e6amIpjqbYSgqzbsKMoNyDA7wtY+nLZy5xUnMA=";
  };

  cargoHash = "sha256-oxfWoUInKrPlQbuDzOinIYONg8pg5nKp8RY4oWUcARY=";

  cargoBuildFlags = [
    "--features"
    "cli"
  ];

  doCheck = false;

  passthru.category = "Utilities";

  meta = with lib; {
    description = "Rust implementation of TOON - Token-Oriented Object Notation for LLM prompts";
    homepage = "https://github.com/toon-format/toon-rust";
    changelog = "https://github.com/toon-format/toon-rust/releases/tag/v${version}";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ antono ];
    mainProgram = "toon";
    platforms = platforms.all;
  };
}
