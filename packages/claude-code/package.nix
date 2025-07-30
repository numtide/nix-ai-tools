{
  lib,
  buildNpmPackage,
  fetchzip,
  nodejs_20,
}:

buildNpmPackage rec {
  pname = "claude-code";
  version = "1.0.63";

  nodejs = nodejs_20; # required for sandboxed Nix builds on Darwin

  src = fetchzip {
    url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${version}.tgz";
    hash = "sha256-6dg4R/f9uMTQdhHi8fqEdbQ3ror6I6ZrMlgp9J/8bcE=";
  };

  npmDepsHash = "sha256-JC80MQmEAuHqDH0aq3wE+AMI9sbgs5snhHe8tFxe+50=";

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
