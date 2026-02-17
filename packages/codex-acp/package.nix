{
  lib,
  fetchFromGitHub,
  fetchurl,
  rustPlatform,
  pkg-config,
  openssl,
}:
let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData)
    version
    hash
    cargoHash
    codexRev
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
