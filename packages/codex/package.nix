{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  gcc-unwrapped,
}:

let
  version = "0.36.0";

  sources = {
    x86_64-linux = {
      url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-x86_64-unknown-linux-musl.tar.gz";
      hash = "sha256-72kockzkx/6vUWELOnWmDPAtQtbV7yzMd8JceBYoQPQ=";
    };
    aarch64-linux = {
      url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-aarch64-unknown-linux-musl.tar.gz";
      hash = "sha256-CrzRea9Edpkghx9XFAgEyz419V6phm6FT7RniSQfTiI=";
    };
    x86_64-darwin = {
      url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-x86_64-apple-darwin.tar.gz";
      hash = "sha256-PHMVAVRNbJKzsgXAp+Xgo/tkaDJ4po/mZNvYbMUFSLM=";
    };
    aarch64-darwin = {
      url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-aarch64-apple-darwin.tar.gz";
      hash = "sha256-0NN1g3DyykSP5Gjp3QewNIeo5uyPpAocSx6lN9FnNHg=";
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
