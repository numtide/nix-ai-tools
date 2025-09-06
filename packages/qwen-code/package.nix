{
  lib,
  nodejs_20,
  buildNpmPackage,
  fetchurl,
  fetchNpmDeps,
  runCommand,
}:
let
  pname = "qwen-code";
  version = "0.0.10";
  srcHash = "sha256-pntZqA9m0ozC0UE9k5qILgGi0+SQ0D5yNKFFCsrODu4=";
  npmDepsHash = "sha256-LNNF3vBsI2Mnj+yRLcj4pBu30r8wTqZazb28ZYH+ec4=";

  src = runCommand "gemini-cli-src-with-lock" { } ''
    mkdir -p $out
    tar -xzf ${
      fetchurl {
        url = "https://registry.npmjs.org/@qwen-code/qwen-code/-/qwen-code-${version}.tgz";
        hash = "${srcHash}";
      }
    } -C $out --strip-components=1
    cp ${./package-lock.json} $out/package-lock.json
  '';
in
buildNpmPackage (finalAttrs: {
  inherit pname version src;

  npmDeps = fetchNpmDeps {
    inherit (finalAttrs) src;
    hash = "${npmDepsHash}";
  };

  dontNpmBuild = true;

  nodejs = nodejs_20;

  passthru.updateScript = ./update.sh;

  meta = {
    description = "Command-line AI workflow tool for Qwen3-Coder models";
    homepage = "https://github.com/QwenLM/qwen-code";
    changelog = "https://github.com/QwenLM/qwen-code/releases";
    license = lib.licenses.asl20;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with lib.maintainers; [
      zimbatm
      lonerOrz
    ];
    platforms = lib.platforms.all;
    mainProgram = "qwen";
  };
})
