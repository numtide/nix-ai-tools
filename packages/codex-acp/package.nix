{
  lib,
  fetchFromGitHub,
  rustPlatform,
  pkg-config,
  openssl,
}:
rustPlatform.buildRustPackage rec {
  pname = "codex-acp";
  version = "0.9.2";

  src = fetchFromGitHub {
    owner = "zed-industries";
    repo = "codex-acp";
    rev = "v${version}";
    hash = "sha256-UtfvuejBnciksytIkTE2yFLTTy5gIB/kbOg7abTBGqQ=";
  };

  cargoHash = "sha256-pCHmYa+5xkON2BoAh7RRe5lQeUqSNgqemt0stHQly6c=";

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
