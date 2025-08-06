{
  lib,
  buildNpmPackage,
  fetchzip,
  nodejs_20,
}:

buildNpmPackage rec {
  pname = "claude-code";
  version = "1.0.69";

  nodejs = nodejs_20; # required for sandboxed Nix builds on Darwin

  src = fetchzip {
    url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${version}.tgz";
    hash = "sha256-uZbe7N3FSAVxNxL7npujJcBFH6ZjnwDz327bZWN2IEM=";
  };

  npmDepsHash = "sha256-a06NT96pVOiz06ZZ9r+1s+oF9U/I7SRJFFAw1e0NkMY=";

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  dontNpmBuild = true;

  AUTHORIZED = "1";

  # Note: Environment variables like DISABLE_AUTOUPDATER and DEV are handled by claudebox
  # which wraps this package. We don't set them here to avoid duplication.

  passthru.updateScript = ./update.sh;

  meta = {
    description = "Agentic coding tool that lives in your terminal, understands your codebase, and helps you code faster";
    homepage = "https://github.com/anthropics/claude-code";
    downloadPage = "https://www.npmjs.com/package/@anthropic-ai/claude-code";
    license = lib.licenses.unfree;
    maintainers = with lib.maintainers; [
      malo
      omarjatoi
    ];
    mainProgram = "claude";
  };
}
