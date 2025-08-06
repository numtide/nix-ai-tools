{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  fetchNpmDeps,
}:

buildNpmPackage (finalAttrs: {
  pname = "qwen-code";
  version = "0.0.4";

  src = fetchFromGitHub {
    owner = "QwenLM";
    repo = "qwen-code";
    rev = "v${finalAttrs.version}";
    hash = "sha256-zVbgJaufJNYxsNuX2JH3tgQeBPalzhgf43sNaifzjYI=";
  };

  npmDeps = fetchNpmDeps {
    inherit (finalAttrs) src;
    hash = "sha256-wQokEy8kbh81xVbuEAtK/YAKIL+u9gLT1utB5YINupE=";
  };

  buildPhase = ''
    runHook preBuild

    npm run generate
    npm run bundle

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    cp -r bundle/* $out/
    patchShebangs $out
    ln -s $out/gemini.js $out/bin/qwen

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
})
