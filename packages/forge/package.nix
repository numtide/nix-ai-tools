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
      url = "https://github.com/antinomyhq/forge/releases/download/v0.119.1/forge-x86_64-unknown-linux-gnu";
      hash = "sha256-RfPcX6PuwoH1d9b6/YtuD+e5iuep4Cs6e8fpqwT2sM4=";
    };
    aarch64-linux = {
      url = "https://github.com/antinomyhq/forge/releases/download/v0.119.1/forge-aarch64-unknown-linux-gnu";
      hash = "sha256-znn/AMKqR3mgxNKE7g4kJhsdMPlXPoZ3DwI5BJ8lagI=";
    };
    x86_64-darwin = {
      url = "https://github.com/antinomyhq/forge/releases/download/v0.119.1/forge-x86_64-apple-darwin";
      hash = "sha256-PE38692vI8vWxKw3zSd9xVbrQ46bWauCx1o+hyjmVRo=";
    };
    aarch64-darwin = {
      url = "https://github.com/antinomyhq/forge/releases/download/v0.119.1/forge-aarch64-apple-darwin";
      hash = "sha256-4AewkA5gqdpvjzfj4Fa7u7qrAcNB0mIWQbBaNycjHhI=";
    };
  };
in
stdenv.mkDerivation rec {
  pname = "forge";
  version = "0.119.1";

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
