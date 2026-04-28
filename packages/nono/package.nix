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
  version = "0.43.0";

  src = fetchFromGitHub {
    owner = "always-further";
    repo = "nono";
    rev = "v${version}";
    hash = "sha256-V0QdcaNxn0bVOK5YZdN/bA//WBJXesDw7P9AzGbRQdk=";
  };

  cargoHash = "sha256-qLL6tq2Q6smB8eb4lsN3VlEStn/7RoXPg23W/yONrog=";

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
