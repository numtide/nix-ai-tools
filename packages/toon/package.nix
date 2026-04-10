{
  lib,
  flake,
  rustPlatform,
  fetchCrate,
}:

let
  data = builtins.fromJSON (builtins.readFile ./hashes.json);
in
rustPlatform.buildRustPackage rec {
  pname = "toon-format";
  version = data.version;

  src = fetchCrate {
    inherit pname version;
    hash = data.hash;
  };

  cargoHash = data.cargoHash;

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
