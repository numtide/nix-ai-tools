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
      url = "https://github.com/antinomyhq/forge/releases/download/v0.122.1/forge-x86_64-unknown-linux-gnu";
      hash = "sha256-je/FwB6iQpHoENcneg/k5rpOopa+rU+LMhLhRijCrXk=";
    };
    aarch64-linux = {
      url = "https://github.com/antinomyhq/forge/releases/download/v0.122.1/forge-aarch64-unknown-linux-gnu";
      hash = "sha256-JIhKI3hfdRSYDBX6cctFkzP7nXWhTPe93ANFBh8Af2A=";
    };
    x86_64-darwin = {
      url = "https://github.com/antinomyhq/forge/releases/download/v0.122.1/forge-x86_64-apple-darwin";
      hash = "sha256-aVHkkCnlG2CtCIzMGUxrwEy5anyifls9lik4dZfVNHw=";
    };
    aarch64-darwin = {
      url = "https://github.com/antinomyhq/forge/releases/download/v0.122.1/forge-aarch64-apple-darwin";
      hash = "sha256-H4kufuowZbwsrKMIIkCAkqvjtaKH4MpaCmkC59lv/Uw=";
    };
  };
in
stdenv.mkDerivation rec {
  pname = "forge";
  version = "0.122.1";

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
