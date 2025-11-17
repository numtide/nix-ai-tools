{
  lib,
  fetchFromGitHub,
  rustPlatform,
  pkg-config,
  openssl,
  libxcb,
  dbus,
}:

rustPlatform.buildRustPackage rec {
  pname = "goose-cli";
  version = "1.14.0";

  src = fetchFromGitHub {
    owner = "block";
    repo = "goose";
    rev = "v${version}";
    hash = "sha256-MEFHVuTejAn1vwTwaxM7XEBSCuFAwLwjptIhKHR6cMM=";
  };

  cargoHash = "sha256-3SiYbiuDCvGnMPUgc58LFobcijGv2qcrbyCIrPdtcTw=";

  nativeBuildInputs = [ pkg-config ];

  buildInputs = [
    openssl
    libxcb
    dbus
  ];

  # Build only the CLI package
  cargoBuildFlags = [
    "--package"
    "goose-cli"
  ];

  # Enable tests with proper environment
  doCheck = true;
  checkPhase = ''
    export HOME=$(mktemp -d)
    export XDG_CONFIG_HOME=$HOME/.config
    export XDG_DATA_HOME=$HOME/.local/share
    export XDG_STATE_HOME=$HOME/.local/state
    export XDG_CACHE_HOME=$HOME/.cache
    mkdir -p $XDG_CONFIG_HOME $XDG_DATA_HOME $XDG_STATE_HOME $XDG_CACHE_HOME

    # Run tests for goose-cli package only
    cargo test --package goose-cli --release
  '';

  meta = with lib; {
    description = "CLI for Goose - a local, extensible, open source AI agent that automates engineering tasks";
    homepage = "https://github.com/block/goose";
    license = licenses.asl20;
    mainProgram = "goose";
  };
}
