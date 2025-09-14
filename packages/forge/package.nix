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
      url = "https://github.com/antinomyhq/forge/releases/download/v0.117.0/forge-x86_64-unknown-linux-gnu";
      hash = "sha256-FUhtXKV9k/zW6vsh+sZlUJhWuZx/opa/JQJuBGrXE1c=";
    };
    aarch64-linux = {
      url = "https://github.com/antinomyhq/forge/releases/download/v0.117.0/forge-aarch64-unknown-linux-gnu";
      hash = "sha256-mp+jS4cpLhuP14njPTaBJGtvxe+Brw02axlBV7u+Iy4=";
    };
    x86_64-darwin = {
      url = "https://github.com/antinomyhq/forge/releases/download/v0.117.0/forge-x86_64-apple-darwin";
      hash = "sha256-YTLZ2kBuYw5TEv97GtAYCQCE9rGBf6sN3IQw/pVmxdc=";
    };
    aarch64-darwin = {
      url = "https://github.com/antinomyhq/forge/releases/download/v0.117.0/forge-aarch64-apple-darwin";
      hash = "sha256-jAlQ9vVfimenpG5fYYq7A9GXRg/4Ort0Ai4PYCsziv4=";
    };
  };
in
stdenv.mkDerivation rec {
  pname = "forge";
  version = "0.117.0";

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
