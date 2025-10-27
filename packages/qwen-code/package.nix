{
  lib,
  buildNpmPackage,
  fetchurl,
  fetchNpmDeps,
  nodejs_22,
  runCommand,
}:

buildNpmPackage (finalAttrs: {
  pname = "qwen-code";
  version = "0.1.0";

  src = fetchurl {
    url = "https://registry.npmjs.org/@qwen-code/qwen-code/-/qwen-code-${finalAttrs.version}.tgz";
    hash = "sha256-gczRnQkE1mrqTWHqnwSsINLsyROD7ZyeuusrMUrusCc=";
  };

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  npmDeps = fetchNpmDeps {
    src = runCommand "qwen-code-src-with-lock" { } ''
      mkdir -p $out
      tar -xzf ${finalAttrs.src} -C $out --strip-components=1
      cp ${./package-lock.json} $out/package-lock.json
    '';
    hash = "sha256-wL1ki/6pZLszdDqtXQWYkZG0FaXjCAOG4r1RoSVoA5Y=";
  };

  npmFlags = [ "--ignore-scripts" ];
  dontNpmBuild = true;

  nodejs = nodejs_22;

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
