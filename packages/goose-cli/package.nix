{
  lib,
  fetchFromGitHub,
  rustPlatform,
  pkg-config,
  openssl,
  libxcb,
  dbus,
  versionCheckHook,
  librusty_v8,
}:

rustPlatform.buildRustPackage rec {
  pname = "goose-cli";
  version = "1.29.0";

  src = fetchFromGitHub {
    owner = "block";
    repo = "goose";
    rev = "v${version}";
    hash = "sha256-CqNITxafZBT230ETC4nxNEP+cvH8R9aCobcuCDP+IHU=";
  };

  cargoHash = "sha256-RUWvbV+/LVSyiHJ/2pseuAP8Nobjr8dMrictDlNgl0c=";

  nativeBuildInputs = [ pkg-config ];

  buildInputs = [
    openssl
    libxcb
    dbus
  ];

  # The v8 package will try to download a `librusty_v8.a` release at build time to our read-only filesystem
  # To avoid this we pre-download the file and export it via RUSTY_V8_ARCHIVE
  env.RUSTY_V8_ARCHIVE = librusty_v8;

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

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  passthru.category = "AI Coding Agents";

  meta = with lib; {
    description = "CLI for Goose - a local, extensible, open source AI agent that automates engineering tasks";
    homepage = "https://github.com/block/goose";
    changelog = "https://github.com/block/goose/releases/tag/v${version}";
    license = licenses.asl20;
    sourceProvenance = with sourceTypes; [ fromSource ];
    mainProgram = "goose";
  };
}
