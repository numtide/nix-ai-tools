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
      url = "https://github.com/antinomyhq/forge/releases/download/v1.1.0/forge-x86_64-unknown-linux-gnu";
      hash = "sha256-FUSKywzmYODJQ12V/vU83g76nS9oN6+3KMzIgENpQCE=";
    };
    aarch64-linux = {
      url = "https://github.com/antinomyhq/forge/releases/download/v1.1.0/forge-aarch64-unknown-linux-gnu";
      hash = "sha256-2Ntu0Ez5pesi+P7OqNh3tuKuQHT2tG1GHTjH9Sb2mRE=";
    };
    x86_64-darwin = {
      url = "https://github.com/antinomyhq/forge/releases/download/v1.1.0/forge-x86_64-apple-darwin";
      hash = "sha256-UQCDho6Ipfqy38CmPAoQtoYDbqyUIHLRbrI8oVCWwM8=";
    };
    aarch64-darwin = {
      url = "https://github.com/antinomyhq/forge/releases/download/v1.1.0/forge-aarch64-apple-darwin";
      hash = "sha256-8uA0LtbshZwhWTBM46uW+0OgKnwVRNm9eanDXDdPflU=";
    };
  };
in
stdenv.mkDerivation rec {
  pname = "forge";
  version = "1.1.0";

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
