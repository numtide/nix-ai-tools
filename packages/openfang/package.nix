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
  version = "0.6.0";

  src = fetchFromGitHub {
    owner = "RightNow-AI";
    repo = "openfang";
    tag = "v${version}";
    hash = "sha256-8/Xb77X2NrzBqR/BRCU5cc6NjmMGfn0sc2qwHj+cZV8=";
  };

  cargoHash = "sha256-SdotDLlmpDpBZCvG9j1mDLLynXxBrEVXpQ6SWWmGsK4=";

  cargoBuildFlags = [
    "--package"
    "openfang-cli"
  ];
  cargoTestFlags = cargoBuildFlags;

  # native-tls needs openssl on Linux only; link nixpkgs openssl instead of
  # upstream's vendored build (avoids perl/clang, inherits security updates).
  env.OPENSSL_NO_VENDOR = "1";

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
