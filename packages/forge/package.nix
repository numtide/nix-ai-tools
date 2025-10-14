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
      url = "https://github.com/antinomyhq/forge/releases/download/v0.126.0/forge-x86_64-unknown-linux-gnu";
      hash = "sha256-MeCY1EA6JWrzokGcC2UTY2x3ALh4qK0N4VVV/Z+FdS4=";
    };
    aarch64-linux = {
      url = "https://github.com/antinomyhq/forge/releases/download/v0.126.0/forge-aarch64-unknown-linux-gnu";
      hash = "sha256-mFA4tMQvctiJtJr5SHYJC6P7INiC4R9EMy8hMoxB8OY=";
    };
    x86_64-darwin = {
      url = "https://github.com/antinomyhq/forge/releases/download/v0.126.0/forge-x86_64-apple-darwin";
      hash = "sha256-4xn0rnDeIMHIKi57fT9PpEEb1c5WqjXQNzT764BrbWI=";
    };
    aarch64-darwin = {
      url = "https://github.com/antinomyhq/forge/releases/download/v0.126.0/forge-aarch64-apple-darwin";
      hash = "sha256-kF8h585tiHaCQCTogLth+ZAPG7Wsx/OLPjz9A2vwda4=";
    };
  };
in
stdenv.mkDerivation rec {
  pname = "forge";
  version = "0.126.0";

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
