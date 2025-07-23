{
  lib,
  stdenv,
  fetchurl,
  nodejs_20,
  makeWrapper,
}:

stdenv.mkDerivation rec {
  pname = "qwen-code";
  version = "0.0.1-alpha.8";

  src = fetchurl {
    url = "https://registry.npmjs.org/@qwen-code/qwen-code/-/qwen-code-${version}.tgz";
    hash = "sha256-GxCK7EZKyF5HBYp3M1dTxmOlXPJSiGifnk6pigFSYOY=";
  };

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/qwen-code
    tar -xzf $src -C $out/lib/qwen-code --strip-components=1

    # Create wrapper script
    mkdir -p $out/bin
    makeWrapper ${nodejs_20}/bin/node $out/bin/qwen \
      --add-flags "$out/lib/qwen-code/bundle/gemini.js"

    runHook postInstall
  '';

  passthru.updateScript = ./update.sh;

  meta = {
    description = "Command-line AI workflow tool for Qwen3-Coder models";
    homepage = "https://github.com/QwenLM/qwen-code";
    changelog = "https://github.com/QwenLM/qwen-code/releases";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [ ];
    platforms = lib.platforms.all;
    mainProgram = "qwen";
  };
}
