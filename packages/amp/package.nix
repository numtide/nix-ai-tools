{
  lib,
  buildNpmPackage,
  fetchurl,
  fetchNpmDeps,
  nodejs_22,
  runCommand,
}:

let
  version = "0.0.1759075281-g254952";
  # First, create a source with package-lock.json included
  srcWithLock = runCommand "amp-src-with-lock" { } ''
    mkdir -p $out
    tar -xzf ${
      fetchurl {
        url = "https://registry.npmjs.org/@sourcegraph/amp/-/amp-0.0.1759075281-g254952.tgz";
        hash = "sha256-5Bd3QySh9dPU/y0T1ltgq24zAelBWEOkAAJG7huT8NA=";
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
    hash = "sha256-83KqQP66+BBTx3tHajlphujvA3PdoryxC6bVVUF82Wo=";
  };

  # The package from npm is already built
  dontNpmBuild = true;

  nodejs = nodejs_22;

  passthru = {
    updateScript = ./update.sh;
  };

  meta = with lib; {
    description = "CLI for Amp, an agentic coding tool in research preview from Sourcegraph";
    homepage = "https://ampcode.com/";
    changelog = "https://github.com/sourcegraph/amp/releases";
    license = licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryBytecode ];
    maintainers = with maintainers; [ ];
    platforms = platforms.all;
    mainProgram = "amp";
  };
}
