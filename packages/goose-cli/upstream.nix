{
  fetchurl,
}:

let
  desktopVersion = "1.32.0";
  cliVersion = "0.17.0";
in
{
  inherit desktopVersion cliVersion;

  cliBinarySrc = fetchurl {
    url = "https://github.com/aaif-goose/goose/releases/download/v${desktopVersion}/goose-x86_64-unknown-linux-gnu.tar.gz";
    hash = "sha256-OJD/FOu+M5TXgc2qaN4vwdY8UNIu5wQn+KNLY9AOwSc=";
  };

  desktopDebSrc = fetchurl {
    url = "https://github.com/aaif-goose/goose/releases/download/v${desktopVersion}/goose_${desktopVersion}_amd64.deb";
    hash = "sha256-Bj4Hgpt36PLfxvc5E93+50Wse1dD/Zh2phnslXzWJYE=";
  };

  cliNpmSrc = fetchurl {
    url = "https://registry.npmjs.org/@aaif/goose/-/goose-${cliVersion}.tgz";
    hash = "sha256-/op6bkUFKLmTzH6iFUqSmbBaCDHfGawr+kTheNfG97o=";
  };
}
