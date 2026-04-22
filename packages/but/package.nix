{
  lib,
  flake,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  openssl,
  sqlite,
  zstd,
  dbus,
  stdenv,
  versionCheckHook,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "but";
  version = "0.19.9";

  src = fetchFromGitHub {
    owner = "gitbutlerapp";
    repo = "gitbutler";
    tag = "release/${finalAttrs.version}";
    hash = "sha256-hUxtvCxLB++33gKc+UNOAns3UFozWTETYJvEr+HcOgU=";
  };

  cargoHash = "sha256-7dF865YPcVp/g6PUs5QRaU3wZ0UmlAgaPGhHsIjIZPY=";

  # Upstream pins a specific stable channel; allow building with nixpkgs' rustc.
  postPatch = ''
    rm -f rust-toolchain.toml
  '';

  nativeBuildInputs = [ pkg-config ];

  buildInputs = [
    openssl
    sqlite
    zstd
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [
    dbus
  ];

  env = {
    # Upstream reads the user-facing version from $VERSION at build time
    # (set by their release pipeline); without it `but --version` reports "dev".
    VERSION = finalAttrs.version;
    # CHANNEL=release makes the binary use the production app identifier.
    CHANNEL = "release";
    OPENSSL_NO_VENDOR = "1";
    ZSTD_SYS_USE_PKG_CONFIG = "1";
    # Avoid generating TypeScript bindings into the source tree during build.
    TS_RS_EXPORT_DIR = "/build/ts-rs";
  };

  cargoBuildFlags = [
    "--package=but"
  ];
  # Signal that the binary is distributed via a package manager so it
  # disables self-update / `but update install` codepaths.
  buildFeatures = [ "but/packaged-but-distribution" ];

  # The workspace test suite requires git fixtures, network access and the
  # full Tauri/GUI stack; the CLI itself is exercised via versionCheckHook.
  doCheck = false;

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckProgramArg = "--version";

  passthru.category = "Workflow & Project Management";

  meta = with lib; {
    description = "GitButler CLI - virtual branches and AI-assisted Git workflow from the terminal";
    homepage = "https://github.com/gitbutlerapp/gitbutler";
    changelog = "https://github.com/gitbutlerapp/gitbutler/releases/tag/release/${finalAttrs.version}";
    # Functional Source License 1.1 (MIT future license)
    license = {
      fullName = "Functional Source License, Version 1.1, MIT Future License";
      url = "https://github.com/gitbutlerapp/gitbutler/blob/master/LICENSE.md";
      free = false;
    };
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ mic92 ];
    mainProgram = "but";
    platforms = platforms.linux ++ platforms.darwin;
  };
})
