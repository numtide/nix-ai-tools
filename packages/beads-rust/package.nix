{
  lib,
  flake,
  rustPlatform,
  fetchFromGitHub,
  versionCheckHook,
}:

rustPlatform.buildRustPackage rec {
  pname = "beads-rust";
  version = "0.1.26";

  src = fetchFromGitHub {
    owner = "Dicklesworthstone";
    repo = "beads_rust";
    tag = "v${version}";
    hash = "sha256-M+/SDjnLNjCIk5dhjMFTQs3YQqcyGoP4OfHIK3EwFHA=";
  };

  cargoHash = "sha256-9qs/hsJcQcJJ5nmoMHC+WgzWAsKEPiWPt9ICdnEDIE4=";

  # fsqlite uses #![feature(peer_credentials_unix_socket)] which requires nightly.
  # RUSTC_BOOTSTRAP=1 enables nightly features on stable rustc.
  env.RUSTC_BOOTSTRAP = 1;

  # Disable self_update feature — doesn't make sense in Nix
  buildNoDefaultFeatures = true;

  # Tests require a git repository context
  doCheck = false;

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  passthru.category = "Workflow & Project Management";

  meta = with lib; {
    description = "Fast Rust port of beads - a local-first issue tracker for git repositories";
    homepage = "https://github.com/Dicklesworthstone/beads_rust";
    changelog = "https://github.com/Dicklesworthstone/beads_rust/releases/tag/v${version}";
    downloadPage = "https://github.com/Dicklesworthstone/beads_rust/releases";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ afterthought ];
    mainProgram = "br";
    platforms = platforms.unix;
  };
}
