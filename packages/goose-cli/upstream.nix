{
  lib,
  fetchurl,
}:

let
  versionData = lib.importJSON ./hashes.json;
  inherit (versionData)
    desktopVersion
    cliVersion
    cliBinaryHash
    desktopDebHash
    cliNpmHash
    npmDepsHash
    ;
in
{
  inherit
    desktopVersion
    cliVersion
    npmDepsHash
    ;

  cliBinarySrc = fetchurl {
    url = "https://github.com/aaif-goose/goose/releases/download/v${desktopVersion}/goose-x86_64-unknown-linux-gnu.tar.gz";
    hash = cliBinaryHash;
  };

  desktopDebSrc = fetchurl {
    url = "https://github.com/aaif-goose/goose/releases/download/v${desktopVersion}/goose_${desktopVersion}_amd64.deb";
    hash = desktopDebHash;
  };

  cliNpmSrc = fetchurl {
    url = "https://registry.npmjs.org/@aaif/goose/-/goose-${cliVersion}.tgz";
    hash = cliNpmHash;
  };
}
