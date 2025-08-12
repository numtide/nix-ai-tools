{
  lib,
  buildNpmPackage,
  fetchurl,
  fetchNpmDeps,
  nodejs_20,
  runCommand,
}:

let
  version = "0.0.1754985669-g62d0e9";
  # First, create a source with package-lock.json included
  srcWithLock = runCommand "amp-src-with-lock" { } ''
    mkdir -p $out
    tar -xzf ${
      fetchurl {
        url = "https://registry.npmjs.org/@sourcegraph/amp/-/amp-0.0.1754985669-g62d0e9.tgz";
        hash = "sha256-bJEXCgZWGcRCSpM78T8VMvKa8QvKEV8IzxWR6sqe27g=";
      }
    } -C $out --strip-components=1
    cp ${./package-lock.json} $out/package-lock.json
  '';
in
buildNpmPackage rec {
  pname = "amp";
  inherit version;

  src = srcWithLock;

  npmDeps = fetchNpmDeps {
    inherit src;
    hash = "sha256-6+oeHEgIJCCou1DAg2GwHUixjEZRB/vK44UfC8mo/XU=";
  };

  # The package from npm is already built
  dontNpmBuild = true;

  nodejs = nodejs_20;

  passthru.updateScript = ./update.sh;

  meta = {
    description = "CLI for Amp, an agentic coding tool in research preview from Sourcegraph";
    homepage = "https://ampcode.com/";
    license = lib.licenses.unfree; # Need to verify the actual license
    maintainers = with lib.maintainers; [ ];
    platforms = lib.platforms.all;
    mainProgram = "amp";
  };
}
