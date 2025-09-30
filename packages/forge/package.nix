{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  autoPatchelfHook,
  gcc-unwrapped,
}:

let
  inherit (stdenv.hostPlatform) system;

  sources = {
    x86_64-linux = {
      url = "https://github.com/antinomyhq/forge/releases/download/v0.121.0/forge-x86_64-unknown-linux-gnu";
      hash = "sha256-vLtvq1gz0AJuUyI2zJQexOorMrO0aOwUtP8eFTizHL4=";
    };
    aarch64-linux = {
      url = "https://github.com/antinomyhq/forge/releases/download/v0.121.0/forge-aarch64-unknown-linux-gnu";
      hash = "sha256-kwKzVLf5+g7X2p+H0UFXNUKaeyfBTyjIVbLFDd0iMFo=";
    };
    x86_64-darwin = {
      url = "https://github.com/antinomyhq/forge/releases/download/v0.121.0/forge-x86_64-apple-darwin";
      hash = "sha256-euYGOHHwqVxONB/9YfmKa8MovR31x9N4NUHbqjxXvtY=";
    };
    aarch64-darwin = {
      url = "https://github.com/antinomyhq/forge/releases/download/v0.121.0/forge-aarch64-apple-darwin";
      hash = "sha256-xQLzrb+T0Ic+rITMdD4N2Dk43w2pWNCRxVgJZicPhl0=";
    };
  };
in
stdenv.mkDerivation rec {
  pname = "forge";
  version = "0.121.0";

  src = fetchurl sources.${system};

  nativeBuildInputs = [
    makeWrapper
  ]
  ++ lib.optionals stdenv.isLinux [
    autoPatchelfHook
  ];

  buildInputs = lib.optionals stdenv.isLinux [
    gcc-unwrapped.lib
  ];

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 $src $out/bin/forge

    runHook postInstall
  '';

  meta = with lib; {
    description = "AI-Enhanced Terminal Development Environment - A comprehensive coding agent that integrates AI capabilities with your development environment";
    homepage = "https://github.com/antinomyhq/forge";
    changelog = "https://github.com/antinomyhq/forge/releases/tag/v${version}";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    maintainers = with maintainers; [ ];
    mainProgram = "forge";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
  };
}
