{
  lib,
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
  version = "0.26.1";

  src = fetchFromGitHub {
    owner = "always-further";
    repo = "nono";
    rev = "v${version}";
    hash = "sha256-cfS2SUuJVkiAIp1bbC/TvNYaHO6wLBMq8w3iiDeZhgk=";
  };

  cargoHash = "sha256-4mXycVJHveQWOdYjKZ7jOuyiePrNZAeDf21CCEvsbp8=";

  buildInputs = [ dbus ];
  nativeBuildInputs = [
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
    platforms = with platforms; unix ++ darwin;
  };
}
