{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchurl,
  rustPlatform,
  pkg-config,
  openssl,
  libcap,
}:
let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData)
    version
    hash
    cargoHash
    codexRev
    codexSrcHash
    nodeVersionHash
    ;

  # codex-core's js_repl/mod.rs uses include_str!("../../../../node-version.txt")
  # which in the original codex monorepo resolves to codex-rs/node-version.txt.
  # Cargo vendoring flattens the workspace structure so this file is missing;
  # we fetch it from the exact commit that Cargo.lock pins.
  nodeVersionFile = fetchurl {
    url = "https://raw.githubusercontent.com/zed-industries/codex/${codexRev}/codex-rs/node-version.txt";
    hash = nodeVersionHash;
  };

  # codex-linux-sandbox's build.rs compiles a vendored copy of bubblewrap (with
  # patches) that lives in codex-rs/vendor/bubblewrap in the main codex repo.
  # Cargo vendoring flattens the workspace so this directory is missing; we
  # fetch the codex source at the pinned rev to provide it via
  # CODEX_BWRAP_SOURCE_DIR.
  codexSrc = fetchFromGitHub {
    owner = "zed-industries";
    repo = "codex";
    rev = codexRev;
    hash = codexSrcHash;
  };
in
rustPlatform.buildRustPackage {
  pname = "codex-acp";
  inherit version;

  src = fetchFromGitHub {
    owner = "zed-industries";
    repo = "codex-acp";
    rev = "v${version}";
    inherit hash;
  };

  inherit cargoHash;

  # Place node-version.txt at the vendor dir root where the include_str! resolves to
  preBuild = ''
    cp ${nodeVersionFile} "$NIX_BUILD_TOP/codex-acp-${version}-vendor/node-version.txt"
  '';

  env = lib.optionalAttrs stdenv.hostPlatform.isLinux {
    # Point the codex-linux-sandbox build.rs at the vendored bubblewrap source
    CODEX_BWRAP_SOURCE_DIR = "${codexSrc}/codex-rs/vendor/bubblewrap";
  };

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [
    openssl
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [
    libcap
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
