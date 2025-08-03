{
  lib,
  buildNpmPackage,
  fetchurl,
  fetchNpmDeps,
  nodejs_20,
  runCommand,
}:

let
  version = "0.1.16";
  # First, create a source with package-lock.json included
  srcWithLock = runCommand "gemini-cli-src-with-lock" { } ''
    mkdir -p $out
    tar -xzf ${
      fetchurl {
        url = "https://registry.npmjs.org/@google/gemini-cli/-/gemini-cli-${version}.tgz";
        hash = "sha256-Dlr1IPkR8r1ByFawGQIZYMOq40FD6ZYR6CX3XR0kdRE=";
      }
    } -C $out --strip-components=1
    cp ${./package-lock.json} $out/package-lock.json
  '';
in
buildNpmPackage rec {
  pname = "gemini-cli";
  inherit version;

  src = srcWithLock;

  npmDeps = fetchNpmDeps {
    inherit src;
    hash = "sha256-H+G+rJZCPfc0+qNwpmbL/957kQq6xM8DwAqrbae83HY=";
  };

  # The package from npm is already built
  dontNpmBuild = true;

  nodejs = nodejs_20;

  passthru.updateScript = ./update.sh;

  meta = {
    description = "AI agent that brings the power of Gemini directly into your terminal";
    homepage = "https://github.com/google-gemini/gemini-cli";
    changelog = "https://github.com/google-gemini/gemini-cli/releases";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [ donteatoreo ];
    platforms = lib.platforms.all;
    mainProgram = "gemini";
  };
}
