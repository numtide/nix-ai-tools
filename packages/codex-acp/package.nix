{
  lib,
  fetchFromGitHub,
  rustPlatform,
  pkg-config,
  openssl,
}:
rustPlatform.buildRustPackage rec {
  pname = "codex-acp";
  version = "0.3.10";

  src = fetchFromGitHub {
    owner = "zed-industries";
    repo = "codex-acp";
    rev = "v${version}";
    hash = "sha256-2uodmFn5xYNZXzaj7M5xCGrJIC1V+xhbUsKautL9YgY=";
  };

  cargoHash = "sha256-ARtSdmec8Ys//nPZh023Bgh2fL5Ye5GxllR4OcpHgDs=";

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [
    openssl
  ];

  doCheck = false;

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
