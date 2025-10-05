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
      url = "https://github.com/antinomyhq/forge/releases/download/v0.123.0/forge-x86_64-unknown-linux-gnu";
      hash = "sha256-lF0qlWxD0lEFHEFEi8iUCU3Hfq7TMI2THEXKDXmlpNo=";
    };
    aarch64-linux = {
      url = "https://github.com/antinomyhq/forge/releases/download/v0.123.0/forge-aarch64-unknown-linux-gnu";
      hash = "sha256-VALsTarxeHVfrss+tv/xD01WUhZzctqRBvTraz+jqOE=";
    };
    x86_64-darwin = {
      url = "https://github.com/antinomyhq/forge/releases/download/v0.123.0/forge-x86_64-apple-darwin";
      hash = "sha256-CtF6puKLt3eAgzEDgQOTx/45lG6vCrh3aK/eHAaKODw=";
    };
    aarch64-darwin = {
      url = "https://github.com/antinomyhq/forge/releases/download/v0.123.0/forge-aarch64-apple-darwin";
      hash = "sha256-g1xq7iztZie9fGDduOmmOQKoWTs6O2HnCce+EpV+mHI=";
    };
  };
in
stdenv.mkDerivation rec {
  pname = "forge";
  version = "0.123.0";

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
