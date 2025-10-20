{
  lib,
  buildNpmPackage,
  fetchurl,
  fetchNpmDeps,
  nodejs_22,
  ripgrep,
  runCommand,
}:

let
  version = "0.0.1760918500-g57ad23";
  # First, create a source with package-lock.json included
  srcWithLock = runCommand "amp-src-with-lock" { } ''
    mkdir -p $out
    tar -xzf ${
      fetchurl {
        url = "https://registry.npmjs.org/@sourcegraph/amp/-/amp-0.0.1760918500-g57ad23.tgz";
        hash = "sha256-dM4UG9b02r5Lcw3MMyuxOJsWF9MYXQBh0NCP95f1b8g=";
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
    hash = "sha256-+tYp4A4TgkOI2V0akugiYsXl50+3CJZuv00kEyiduvU=";
  };

  # The package from npm is already built
  dontNpmBuild = true;

  nodejs = nodejs_22;

  postInstall = ''
    wrapProgram $out/bin/amp \
      --prefix PATH : ${lib.makeBinPath [ ripgrep ]} \
      --set AMP_SKIP_UPDATE_CHECK 1
  '';

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
