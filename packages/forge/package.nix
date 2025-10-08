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
      url = "https://github.com/antinomyhq/forge/releases/download/v0.123.3/forge-x86_64-unknown-linux-gnu";
      hash = "sha256-gqB4JYzq86Y71jVp06M8FdZY6B8gCnB21YnK1LxwMKs=";
    };
    aarch64-linux = {
      url = "https://github.com/antinomyhq/forge/releases/download/v0.123.3/forge-aarch64-unknown-linux-gnu";
      hash = "sha256-wW5A/amCLe25O4w5/bYwDI9nufV2ImR44W0+J3Qgc2s=";
    };
    x86_64-darwin = {
      url = "https://github.com/antinomyhq/forge/releases/download/v0.123.3/forge-x86_64-apple-darwin";
      hash = "sha256-p+epEIjVsfivZz10RjSb9tdlTy+MypnVFiULyPe1VOs=";
    };
    aarch64-darwin = {
      url = "https://github.com/antinomyhq/forge/releases/download/v0.123.3/forge-aarch64-apple-darwin";
      hash = "sha256-DjVq2IE5lx6SXgaT+5PALSdE6aPe8oV//9RSYiNNZ/k=";
    };
  };
in
stdenv.mkDerivation rec {
  pname = "forge";
  version = "0.123.3";

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
