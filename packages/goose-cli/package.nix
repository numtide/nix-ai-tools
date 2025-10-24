{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  libxcb,
  gcc,
}:

let
  version = "1.12.0";

  sources = {
    x86_64-linux = {
      url = "https://github.com/block/goose/releases/download/v${version}/goose-x86_64-unknown-linux-gnu.tar.bz2";
      hash = "sha256-0PJ6WF4SMK+COsWR3UTeqoDfSEuvo3ryDQNRRrrSjVI=";
    };
    aarch64-linux = {
      url = "https://github.com/block/goose/releases/download/v${version}/goose-aarch64-unknown-linux-gnu.tar.bz2";
      hash = "sha256-oSHrx0OpeyMDfAvnUGDB+SbfonCCcLctBg/1WDNKajc=";
    };
    x86_64-darwin = {
      url = "https://github.com/block/goose/releases/download/v${version}/goose-x86_64-apple-darwin.tar.bz2";
      hash = "sha256-snVpbE+n1rXTCXsyF/UpNI6USfaGfIzDvsOGA1rWGqE=";
    };
    aarch64-darwin = {
      url = "https://github.com/block/goose/releases/download/v${version}/goose-aarch64-apple-darwin.tar.bz2";
      hash = "sha256-Qz9iU67vvFSBJlBhwh0wHCrvUZqnmNgnfV5w1JPIbNo=";
    };
  };

  source =
    sources.${stdenv.hostPlatform.system}
      or (throw "Unsupported system: ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation rec {
  pname = "goose-cli";
  inherit version;

  src = fetchurl source;

  nativeBuildInputs = [
    makeWrapper
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [
    autoPatchelfHook
  ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    libxcb
    gcc.cc.lib
  ];

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    cp goose $out/bin/goose
    chmod +x $out/bin/goose

    runHook postInstall
  '';

  meta = with lib; {
    description = "CLI for Goose - a local, extensible, open source AI agent that automates engineering tasks";
    homepage = "https://github.com/block/goose";
    license = licenses.asl20;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    maintainers = with maintainers; [ ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    mainProgram = "goose";
  };
}
