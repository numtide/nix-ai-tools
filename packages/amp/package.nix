{
  lib,
  buildNpmPackage,
  fetchurl,
  fetchNpmDeps,
  nodejs_20,
  runCommand,
}:

let
  version = "0.0.1755158498-g04711f";
  # First, create a source with package-lock.json included
  srcWithLock = runCommand "amp-src-with-lock" { } ''
    mkdir -p $out
    tar -xzf ${
      fetchurl {
        url = "https://registry.npmjs.org/@sourcegraph/amp/-/amp-0.0.1755158498-g04711f.tgz";
        hash = "sha256-DZ15Qd8Y3A3V3LmbojyYg00ZGcF8EvBD14MQ2+uFzoA=";
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
    hash = "sha256-v17dCzk9HR+9MHAyboBlh2X1WPPg1wnJ7TWcfA3oy50=";
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
