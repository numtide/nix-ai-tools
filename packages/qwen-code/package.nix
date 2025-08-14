{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  fetchNpmDeps,
}:

buildNpmPackage (finalAttrs: {
  pname = "qwen-code";
  version = "0.0.6";

  src = fetchFromGitHub {
    owner = "QwenLM";
    repo = "qwen-code";
    rev = "v${finalAttrs.version}";
    hash = "sha256-s4+1hqdlJh5jOy6uZz608n5DzuBR+v/s+7D85oFwQIY=";
  };

  npmDeps = fetchNpmDeps {
    inherit (finalAttrs) src;
    hash = "sha256-cGO66hQxgpoxphtt/BPPDIBuAG8yQseCdzUdAO2mkr4=";
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
