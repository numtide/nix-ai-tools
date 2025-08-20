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
      url = "https://github.com/antinomyhq/forge/releases/download/v0.109.2/forge-x86_64-unknown-linux-gnu";
      hash = "sha256-k4/Jc+zdGuSOZcvSmgjs8JUkxqMa2Bt4M4NQNRQEBA0=";
    };
    aarch64-linux = {
      url = "https://github.com/antinomyhq/forge/releases/download/v0.109.2/forge-aarch64-unknown-linux-gnu";
      hash = "sha256-H9K5hNtdUs72OQ0xY806QTPBnPd/6PbukLox5TLZZOA=";
    };
    x86_64-darwin = {
      url = "https://github.com/antinomyhq/forge/releases/download/v0.109.2/forge-x86_64-apple-darwin";
      hash = "sha256-odPJOr3s5dJApDfFpMHlskYwAr5gxJdi8sZRi+ywt2o=";
    };
    aarch64-darwin = {
      url = "https://github.com/antinomyhq/forge/releases/download/v0.109.2/forge-aarch64-apple-darwin";
      hash = "sha256-NXzhIHkIbTJBosc/+Hbwms9pAVGthEmYAJKZwHiLayM=";
    };
  };
in
stdenv.mkDerivation rec {
  pname = "forge";
  version = "0.109.2";

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
