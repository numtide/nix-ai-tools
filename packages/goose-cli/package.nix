{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  openssl,
  stdenv,
  darwin,
}:

rustPlatform.buildRustPackage rec {
  pname = "goose-cli";
  version = "1.3.1";

  src = fetchFromGitHub {
    owner = "block";
    repo = "goose";
    rev = "v${version}";
    hash = "sha256-bb+GB+mBsnTwCOl8iuSUjm35mrhJGNdlyyU9EKSvlME=";
  };

  cargoHash = "sha256-AHAB3Bmyb+nkYCKWIo4ARkiidTjAaGIA0rz24QaF6Co=";

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [
    openssl
  ] ++ lib.optionals stdenv.isDarwin [
    darwin.apple_sdk.frameworks.Security
    darwin.apple_sdk.frameworks.SystemConfiguration
  ];

  # Build the goose CLI binary
  cargoBuildFlags = [ "--package" "goose-cli" ];

  # Skip tests for now
  doCheck = false;

  meta = with lib; {
    description = "CLI for Goose - a local, extensible, open source AI agent that automates engineering tasks";
    homepage = "https://github.com/block/goose";
    changelog = "https://github.com/block/goose/releases/tag/v${version}";
    license = licenses.asl20;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with maintainers; [ ];
    mainProgram = "goose";
    platforms = platforms.all;
  };
}
