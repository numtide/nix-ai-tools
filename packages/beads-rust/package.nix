{
  lib,
  flake,
  rustPlatform,
  fetchFromGitHub,
  versionCheckHook,
}:

let
  data = builtins.fromJSON (builtins.readFile ./hashes.json);

  # Upstream uses [patch.crates-io] with local path deps pointing at sibling
  # checkouts of frankensqlite and asupersync.  Fetch them separately and place
  # them where Cargo expects.
  # https://github.com/Dicklesworthstone/beads_rust/issues/183
  frankensqlite = fetchFromGitHub {
    owner = "Dicklesworthstone";
    repo = "frankensqlite";
    inherit (data.frankensqlite) rev hash;
  };

  # frankensqlite workspace depends on asupersync via path = "../asupersync"
  asupersync = fetchFromGitHub {
    owner = "Dicklesworthstone";
    repo = "asupersync";
    inherit (data.asupersync) rev hash;
  };
in
rustPlatform.buildRustPackage {
  pname = "beads-rust";
  inherit (data) version cargoHash;

  src = fetchFromGitHub {
    owner = "Dicklesworthstone";
    repo = "beads_rust";
    tag = "v${data.version}";
    inherit (data) hash;
  };

  postUnpack = ''
    cp -r ${frankensqlite} frankensqlite
    chmod -R u+w frankensqlite
    cp -r ${asupersync} asupersync
    chmod -R u+w asupersync
  '';

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
    changelog = "https://github.com/Dicklesworthstone/beads_rust/releases/tag/v${data.version}";
    downloadPage = "https://github.com/Dicklesworthstone/beads_rust/releases";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ afterthought ];
    mainProgram = "br";
    platforms = platforms.unix;
  };
}
