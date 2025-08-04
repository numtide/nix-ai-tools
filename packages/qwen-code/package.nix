{
  lib,
  stdenv,
  fetchzip,
  nodejs_20,
  makeWrapper,
}:

stdenv.mkDerivation rec {
  pname = "qwen-code";
  version = "0.0.4";

  src = fetchzip {
    url = "https://registry.npmjs.org/@qwen-code/qwen-code/-/qwen-code-${version}.tgz";
    hash = "sha256-19qnhdWrz+Y7WJ4gv7yzKU0kpngbu0tZZ2ULuMga43Q=";
  };

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/node_modules/@qwen-code/qwen-code
    cp -r * $out/lib/node_modules/@qwen-code/qwen-code/

    # Create wrapper script
    mkdir -p $out/bin
    makeWrapper ${nodejs_20}/bin/node $out/bin/qwen \
      --add-flags "$out/lib/node_modules/@qwen-code/qwen-code/bundle/gemini.js"

    runHook postInstall
  '';

  meta = {
    description = "Command-line AI workflow tool for Qwen3-Coder models";
    homepage = "https://github.com/QwenLM/qwen-code";
    changelog = "https://github.com/QwenLM/qwen-code/releases";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [ zimbatm ];
    platforms = lib.platforms.all;
    mainProgram = "qwen";
  };
}
