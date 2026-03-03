{
  lib,
  flake,
  rustPlatform,
  fetchFromGitHub,
  versionCheckHook,
  versionCheckHomeHook,
}:

rustPlatform.buildRustPackage rec {
  pname = "zeroclaw";
  version = "0.2.0";

  src = fetchFromGitHub {
    owner = "zeroclaw-labs";
    repo = "zeroclaw";
    tag = "v${version}";
    hash = "sha256-A++fIyS5EgVpPBW1PirT0u3u8LYdFCYdg5SxsBdMx1A=";
  };

  cargoHash = "sha256-7olFtUaTmn/Ka/tczDi9GgGKf5P5Qc7hiiSNQF9sizE=";

  # Tests require runtime configuration and network access
  doCheck = false;

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];

  passthru.category = "AI Assistants";

  meta = {
    description = "Fast, small, and fully autonomous AI assistant infrastructure";
    homepage = "https://github.com/zeroclaw-labs/zeroclaw";
    changelog = "https://github.com/zeroclaw-labs/zeroclaw/releases";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ commandodev ];
    mainProgram = "zeroclaw";
    platforms = lib.platforms.unix;
  };
}
