{
  lib,
  flake,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage rec {
  pname = "zeroclaw";
  version = "0.1.1";

  src = fetchFromGitHub {
    owner = "zeroclaw-labs";
    repo = "zeroclaw";
    tag = "v${version}";
    hash = "sha256-CE+kltmKxvkqJl5S3gI4XWXifVxMF6bOn7TRosiXjOs=";
  };

  cargoHash = "sha256-bIrUcZCELmrpg/pMsbpB6VkQ/5MJ2IAQoninMnok4gU=";

  # Tests require runtime configuration and network access
  doCheck = false;

  # The 0.1.1 binary still reports version 0.1.0 (upstream bug), so skip version check
  doInstallCheck = false;

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
