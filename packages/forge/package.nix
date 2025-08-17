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
      url = "https://github.com/antinomyhq/forge/releases/download/v0.108.0/forge-x86_64-unknown-linux-gnu";
      hash = "sha256-MIWD0ieXp1ZN8ROZCHpqPtyTMdgeRtqm1vOqL/er09g=";
    };
    aarch64-linux = {
      url = "https://github.com/antinomyhq/forge/releases/download/v0.108.0/forge-aarch64-unknown-linux-gnu";
      hash = "sha256-VO6lWKDoyxOEW6vknQugbOHEpfL96CUg2gY8IPZhfoA=";
    };
    x86_64-darwin = {
      url = "https://github.com/antinomyhq/forge/releases/download/v0.108.0/forge-x86_64-apple-darwin";
      hash = "sha256-IKgAcGfYd4nNdEkgXZWKeuYXTxyw4St57TDRj/ykmiU=";
    };
    aarch64-darwin = {
      url = "https://github.com/antinomyhq/forge/releases/download/v0.108.0/forge-aarch64-apple-darwin";
      hash = "sha256-ZRdBK9HqvP3dBON8It6vE0ghNMWVbnfgA9b+GbtitBc=";
    };
  };
in
stdenv.mkDerivation rec {
  pname = "forge";
  version = "0.108.0";

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
