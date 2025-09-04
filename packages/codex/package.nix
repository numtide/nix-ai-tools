{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  gcc-unwrapped,
}:

let
  version = "0.29.0";

  sources = {
    x86_64-linux = {
      url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-x86_64-unknown-linux-musl.tar.gz";
      hash = "sha256-kFb4JxyNPmIGnnMaSoOzEHmmPvKHWN8T9KgzaOs2Ugs=";
    };
    aarch64-linux = {
      url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-aarch64-unknown-linux-musl.tar.gz";
      hash = "sha256-91Q1xFITD1u1g5YNmM+2PPpgYk3iwFVLhlaLWmA0d5M=";
    };
    x86_64-darwin = {
      url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-x86_64-apple-darwin.tar.gz";
      hash = "sha256-+9OKSyRuHmTCqj9B3wbDVJZumJ8Dahac8PHlLxOteR0=";
    };
    aarch64-darwin = {
      url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-aarch64-apple-darwin.tar.gz";
      hash = "sha256-i8AMMmv4VktpuywVS7dFIHzistNZ522U/PiroV1AxgI=";
    };
  };

  source =
    sources.${stdenv.hostPlatform.system}
      or (throw "Unsupported platform: ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "codex";
  inherit version;

  src = fetchurl {
    inherit (source) url hash;
  };

  nativeBuildInputs = lib.optionals stdenv.isLinux [ autoPatchelfHook ];

  buildInputs = lib.optionals stdenv.isLinux [ gcc-unwrapped.lib ];

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    install -D -m755 codex-* $out/bin/codex

    runHook postInstall
  '';

  passthru = {
    updateScript = ./update.sh;
  };

  meta = with lib; {
    description = "OpenAI Codex CLI - a coding agent that runs locally on your computer";
    homepage = "https://github.com/openai/codex";
    downloadPage = "https://github.com/openai/codex/releases";
    changelog = "https://github.com/openai/codex/releases/tag/rust-v${version}";
    license = licenses.asl20;
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    maintainers = with maintainers; [ ];
    mainProgram = "codex";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
  };
}
