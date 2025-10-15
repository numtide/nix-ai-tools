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
  version = "1.10.1";

  sources = {
    x86_64-linux = {
      url = "https://github.com/block/goose/releases/download/v${version}/goose-x86_64-unknown-linux-gnu.tar.bz2";
      hash = "sha256-grhuAXX0bx5sxZK3R4GBh9EJ8XxqqzJUSpfnrFT1ZfA=";
    };
    aarch64-linux = {
      url = "https://github.com/block/goose/releases/download/v${version}/goose-aarch64-unknown-linux-gnu.tar.bz2";
      hash = "sha256-tWhReUniyMICmtRCPKHt0B/ZVZ7J6bTk4V7HRYIMQsY=";
    };
    x86_64-darwin = {
      url = "https://github.com/block/goose/releases/download/v${version}/goose-x86_64-apple-darwin.tar.bz2";
      hash = "sha256-R0yzETcBVfMDvbLRM4GH9N+M7qbW0s6A0CgciAq5f3w=";
    };
    aarch64-darwin = {
      url = "https://github.com/block/goose/releases/download/v${version}/goose-aarch64-apple-darwin.tar.bz2";
      hash = "sha256-Im9+4QX3mVyyR3DeBZmKNxE2zrCXdnEzbpWHDOc78g8=";
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
