{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  gcc-unwrapped,
}:

let
  version = "0.34.0";

  sources = {
    x86_64-linux = {
      url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-x86_64-unknown-linux-musl.tar.gz";
      hash = "sha256-VxXcM0lHNhVVt875Bism1s1pLdb2R4HLKEkTfrx6jlk=";
    };
    aarch64-linux = {
      url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-aarch64-unknown-linux-musl.tar.gz";
      hash = "sha256-6J01SAzocOLYPRC29ahkEdcoWS82VE2tkUxpfBgCz8w=";
    };
    x86_64-darwin = {
      url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-x86_64-apple-darwin.tar.gz";
      hash = "sha256-KywRHvQsUNUsPBhMsnxFKFQtmWWgzVtNqndUt5I5tsM=";
    };
    aarch64-darwin = {
      url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-aarch64-apple-darwin.tar.gz";
      hash = "sha256-IV6090p6pK/2ElUG92bAru/QpXFs7+yVHJgMevcOVYs=";
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
