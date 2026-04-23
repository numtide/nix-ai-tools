{
  lib,
  stdenv,
  rustPlatform,
  fetchFromGitHub,
  dbus,
  pkg-config,
  autoPatchelfHook,
  versionCheckHook,
  ...
}:

rustPlatform.buildRustPackage rec {
  pname = "nono";
  version = "0.40.1";

  src = fetchFromGitHub {
    owner = "always-further";
    repo = "nono";
    rev = "v${version}";
    hash = "sha256-CRqqCON0yV81U/DeCGK1vcrjfM4zycUzvXHq/WeoB+U=";
  };

  cargoHash = "sha256-kcDg1bAwUOi/CmKiVeyg40mF+Bx0z4mH8d6Iq1QXDQU=";

  # keyring uses sync-secret-service (dbus) on Linux, apple-native on Darwin
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [ dbus ];
  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    pkg-config
    autoPatchelfHook
  ];

  doCheck = false;

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
  ];

  passthru.category = "Utilities";

  meta = with lib; {
    description = "Kernel-enforced agent sandbox. Capability-based isolation with secure key management, atomic rollback, cryptographic immutable audit chain of provenance. Run your agents in a zero-trust environment.";
    homepage = "https://nono.sh/";
    changelog = "https://github.com/always-further/nono/releases/tag/v${version}";
    license = licenses.asl20;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with maintainers; [ pogobanane ];
    mainProgram = "nono";
    platforms = platforms.unix;
  };
}
