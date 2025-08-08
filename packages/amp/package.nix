{
  lib,
  buildNpmPackage,
  fetchurl,
  fetchNpmDeps,
  nodejs_20,
  runCommand,
}:

let
  version = "0.0.1754626568-ga6faed";
  # First, create a source with package-lock.json included
  srcWithLock = runCommand "amp-src-with-lock" { } ''
    mkdir -p $out
    tar -xzf ${
      fetchurl {
        url = "https://registry.npmjs.org/@sourcegraph/amp/-/amp-${version}.tgz";
        hash = "sha256-kSsRIsbIBbwPQlALV8euQVA5qGL6U6mTm9K1tmMCdaw=";
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
    hash = "sha256-34A7ZrXpLcxGfp9SNNvkPtgjG7r57qjHTawkc6NwevQ=";
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
