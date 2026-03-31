{
  lib,
  flake,
  rustPlatform,
  fetchFromGitHub,
  versionCheckHook,
  versionCheckHomeHook,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "zeroclaw";
  version = "0.1.7-beta.1";

  src = fetchFromGitHub {
    owner = "openagen";
    repo = "zeroclaw";
    tag = "v${finalAttrs.version}";
    hash = "sha256-lFehpOKJJuOrbAcMHPu2ZAFYKz/jb1g0tlXkJ8wWncE=";
  };

  cargoHash = "sha256-sbC+fdMzjrx0dF5zHBHzMgZeIPQth1oXNqilooVZF8s=";

  # rust-embed picks up web/dist/ at compile time; upstream commits the
  # prebuilt bundle so no npm build step is needed.
  # Ensure the embedded path resolves inside the sandbox.
  RUST_EMBED_STRICT = "1";

  # Tests require runtime configuration and network access
  doCheck = false;

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];
  # Cargo.toml reports "0.1.7" even though the tag is "v0.1.7-beta.1".
  # Strip the pre-release suffix before comparing.
  preVersionCheck = ''
    version=''${version%%-*}
  '';

  passthru.category = "AI Assistants";

  meta = {
    description = "Fast, small, and fully autonomous AI assistant infrastructure";
    homepage = "https://github.com/openagen/zeroclaw";
    changelog = "https://github.com/openagen/zeroclaw/releases/tag/v${finalAttrs.version}";
    license = with lib.licenses; [
      mit
      asl20
    ];
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ commandodev ];
    mainProgram = "zeroclaw";
    platforms = lib.platforms.unix;
  };
})
