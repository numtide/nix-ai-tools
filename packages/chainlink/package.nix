{
  lib,
  flake,
  fetchFromGitHub,
  rustPlatform,
  versionCheckHook,
}:

rustPlatform.buildRustPackage rec {
  pname = "chainlink";
  version = "1.4";

  src = fetchFromGitHub {
    owner = "dollspace-gay";
    repo = "chainlink";
    rev = "chainlink-${version}";
    hash = "sha256-dm9Ck2poEDOpX8WEH3cVwiNsepXFGWFyGOfqZsN72+E=";
  };

  # The Rust crate is in the chainlink subdirectory
  cargoRoot = "chainlink";
  buildAndTestSubdir = "chainlink";

  cargoHash = "sha256-vBIA+N8Dro8B9XsbSxFIC3wzwSwHlBF9mBprlKI7YQA=";

  # Upstream doesn't update Cargo.toml version, patch it to match release tag
  postPatch = ''
    substituteInPlace chainlink/Cargo.toml \
      --replace-fail 'version = "0.1.0"' 'version = "${version}.0"'
  '';

  # Tests require a writable filesystem
  doCheck = false;

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  passthru.category = "Workflow & Project Management";

  meta = with lib; {
    description = "Simple, lean issue tracker CLI designed for AI-assisted development";
    homepage = "https://github.com/dollspace-gay/chainlink";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ Chickensoupwithrice ];
    mainProgram = "chainlink";
    platforms = platforms.all;
  };
}
