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
  version = "0.5.4";

  src = fetchFromGitHub {
    owner = "zeroclaw-labs";
    repo = "zeroclaw";
    tag = "v${version}";
    hash = "sha256-RFPTjtAXZbAaigcInwvN7aTrzSn6uNK2P0q1rVD2mTI=";
  };

  cargoHash = "sha256-LOBgu7R5lnMpxzGUzwTeMMWYYFaCQcaZZWq/ATPN+9A=";

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
