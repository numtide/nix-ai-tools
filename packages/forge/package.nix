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
      url = "https://github.com/antinomyhq/forge/releases/download/v0.111.0/forge-x86_64-unknown-linux-gnu";
      hash = "sha256-fK3ubobJVqd1Pkw3Sg5wS6dQJ2YOZzukG1sTEUERwhA=";
    };
    aarch64-linux = {
      url = "https://github.com/antinomyhq/forge/releases/download/v0.111.0/forge-aarch64-unknown-linux-gnu";
      hash = "sha256-Q17UQ14eIZJXV6FwK2S+13tP1Y7dmF9WQEfOZbYqAAo=";
    };
    x86_64-darwin = {
      url = "https://github.com/antinomyhq/forge/releases/download/v0.111.0/forge-x86_64-apple-darwin";
      hash = "sha256-T1Uf047JgUrEfOP8Q1on0KFmcOZUEwAlyLyHonlBUs4=";
    };
    aarch64-darwin = {
      url = "https://github.com/antinomyhq/forge/releases/download/v0.111.0/forge-aarch64-apple-darwin";
      hash = "sha256-2pMGyIajgT/aK0x6BpnVUwQAUDjT1p3lHxVT+JGOes8=";
    };
  };
in
stdenv.mkDerivation rec {
  pname = "forge";
  version = "0.111.0";

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
