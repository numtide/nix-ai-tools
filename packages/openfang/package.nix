{
  lib,
  flake,
  fetchFromGitHub,
  rustPlatform,
  pkg-config,
  openssl,
  stdenv,
  versionCheckHook,
}:

rustPlatform.buildRustPackage rec {
  pname = "openfang";
  version = "0.6.2";

  src = fetchFromGitHub {
    owner = "RightNow-AI";
    repo = "openfang";
    tag = "v${version}";
    hash = "sha256-34gwd2+0pTjDm+tbpOJVLsDovaiSWfH/OVx18vVg4YE=";
  };

  cargoHash = "sha256-51eY5J1ms1ZecdFAj/CTVriN6NC1a/L5nUmxQ2z3bOo=";

  cargoBuildFlags = [
    "--package"
    "openfang-cli"
  ];
  cargoTestFlags = cargoBuildFlags;

  env = {
    # native-tls needs openssl on Linux only; link nixpkgs openssl instead of
    # upstream's vendored build (avoids perl/clang, inherits security updates).
    OPENSSL_NO_VENDOR = "1";
    # Upstream sets lto=true + codegen-units=1, making the final link a
    # single-threaded fat-LTO over ~450 crates (wasmtime/cranelift). Override
    # to keep CI build times reasonable.
    CARGO_PROFILE_RELEASE_LTO = "off";
    CARGO_PROFILE_RELEASE_CODEGEN_UNITS = "16";
  };

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [ pkg-config ];
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [ openssl ];

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckProgramArg = "--version";

  passthru.category = "AI Coding Agents";

  meta = {
    description = "Open-source Agent OS built in Rust — CLI for the OpenFang platform";
    homepage = "https://github.com/RightNow-AI/openfang";
    changelog = "https://github.com/RightNow-AI/openfang/releases/tag/v${version}";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ viniciuspalma ];
    mainProgram = "openfang";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
  };
}
