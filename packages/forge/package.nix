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
      url = "https://github.com/antinomyhq/forge/releases/download/v1.3.0/forge-x86_64-unknown-linux-gnu";
      hash = "sha256-nE+oybH1RGPdForjOOnhgD7M7nTZa1hxb6+G1tCf7Gk=";
    };
    aarch64-linux = {
      url = "https://github.com/antinomyhq/forge/releases/download/v1.3.0/forge-aarch64-unknown-linux-gnu";
      hash = "sha256-kYNy4oOhJOpFXmtF68NlWXF02G4d9zwIdQqdFWrgHJY=";
    };
    x86_64-darwin = {
      url = "https://github.com/antinomyhq/forge/releases/download/v1.3.0/forge-x86_64-apple-darwin";
      hash = "sha256-GC1qqPLty4eOf/26ipmDT1t+POwApvQerzQocCGDCEc=";
    };
    aarch64-darwin = {
      url = "https://github.com/antinomyhq/forge/releases/download/v1.3.0/forge-aarch64-apple-darwin";
      hash = "sha256-HAZ7D+5PmcMLGPfqf1EKOS2KbB1wOJ/eCPsvSnB+hN0=";
    };
  };
in
stdenv.mkDerivation rec {
  pname = "forge";
  version = "1.3.0";

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
