{
  lib,
  stdenv,
  fetchurl,
  nodejs_20,
  makeWrapper,
  nix-update-script,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "qwen-code";
  version = "0.0.12";

  src = fetchurl {
    url = "https://github.com/QwenLM/qwen-code/releases/download/v${finalAttrs.version}/gemini.js";
    hash = "sha256-QzvlPP8DYK/tOinn5glTZWvjgACP1SrR6V1QgK5FrgU=";
  };

  dontUnpack = true;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/lib/qwen-code
    cp $src $out/lib/qwen-code/gemini.js

    makeWrapper ${nodejs_20}/bin/node $out/bin/qwen \
      --add-flags "$out/lib/qwen-code/gemini.js"

    runHook postInstall
  '';

  meta = {
    description = "Command-line AI workflow tool for Qwen3-Coder models";
    homepage = "https://github.com/QwenLM/qwen-code";
    changelog = "https://github.com/QwenLM/qwen-code/releases";
    license = lib.licenses.asl20;
    sourceProvenance = with lib.sourceTypes; [ binaryBytecode ];
    maintainers = with lib.maintainers; [
      zimbatm
      lonerOrz
    ];
    platforms = lib.platforms.all;
    mainProgram = "qwen";
  };
})
