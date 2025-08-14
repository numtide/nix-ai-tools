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
      url = "https://github.com/antinomyhq/forge/releases/download/v0.107.0/forge-x86_64-unknown-linux-gnu";
      hash = "sha256-lwlJt2julVlLsMP+zQ9lHK7KIKMvovCCX/e+yJJ+IH8=";
    };
    aarch64-linux = {
      url = "https://github.com/antinomyhq/forge/releases/download/v0.107.0/forge-aarch64-unknown-linux-gnu";
      hash = "sha256-BKhqtxhMiRnsCCkMhZG2VjsjPqn7yH6St8s75vvUMO0=";
    };
    x86_64-darwin = {
      url = "https://github.com/antinomyhq/forge/releases/download/v0.107.0/forge-x86_64-apple-darwin";
      hash = "sha256-xL2Wnlxj4dzEkqhk7ps499aC1qCA3XivMgg0TT1DMe4=";
    };
    aarch64-darwin = {
      url = "https://github.com/antinomyhq/forge/releases/download/v0.107.0/forge-aarch64-apple-darwin";
      hash = "sha256-G8CSXmJHYNCMTQwkzX4xpfJbexALiTZb/2DbBnJy6pM=";
    };
  };
in
stdenv.mkDerivation rec {
  pname = "forge";
  version = "0.107.0";

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
