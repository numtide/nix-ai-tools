{
  lib,
  fetchFromGitHub,
  fetchurl,
  rustPlatform,
  pkg-config,
  openssl,
}:
rustPlatform.buildRustPackage rec {
  pname = "codex-acp";
  version = "0.9.3";

  src = fetchFromGitHub {
    owner = "zed-industries";
    repo = "codex-acp";
    rev = "v${version}";
    hash = "sha256-wbdFjysjWGxWKjNyPNDkZm3Twiq8BQ0YtkvpmE7BfqM=";
  };

  cargoHash = "sha256-zqv8P8rko5KEV51/0P6WAsLwWNUjoa1RwxJAZYmjO48=";

  # The codex-core dependency needs node-version.txt from the codex workspace root
  # This file is not included in the vendored dependencies, so we fetch it separately
  nodeVersionFile = fetchurl {
    url = "https://raw.githubusercontent.com/zed-industries/codex/1591f20ca07bbde58358364020eff9f2cf24f192/codex-rs/node-version.txt";
    hash = "sha256-q/bOpgF6/0K3MDKXAC+bi1Rb/vCHNhKZpNDbhyYH+oc=";
  };

  preBuild = ''
    # Debug: Check what directories exist
    echo "Current directory: $(pwd)"
    echo "Directory contents:"
    ls -la
    echo "Looking for vendored codex-core:"
    find . -name "*codex-core*" -type d || true
    
    # Copy node-version.txt to the cargo vendor directory where codex-core expects it
    # The file should be at the workspace root (4 levels up from js_repl/mod.rs)
    if [ -d "target/release/build" ]; then
      cp ${nodeVersionFile} target/release/build/node-version.txt || true
    fi
    # Try multiple possible locations
    for dir in deps target/deps cargo-vendor-dir codex-acp-0.9.3-vendor; do
      if [ -d "$dir/codex-core-0.0.0" ]; then
        echo "Found codex-core at $dir/codex-core-0.0.0"
        cp ${nodeVersionFile} $dir/codex-core-0.0.0/node-version.txt
      fi
    done
  '';

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [
    openssl
  ];

  doCheck = false;

  passthru.category = "ACP Ecosystem";

  meta = with lib; {
    description = "An ACP-compatible coding agent powered by Codex";
    homepage = "https://github.com/zed-industries/codex-acp";
    changelog = "https://github.com/zed-industries/codex-acp/releases/tag/v${version}";
    license = licenses.asl20;
    maintainers = with maintainers; [ ];
    platforms = platforms.unix;
    sourceProvenance = with sourceTypes; [ fromSource ];
    mainProgram = "codex-acp";
  };
}
