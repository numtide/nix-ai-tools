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
      url = "https://github.com/antinomyhq/forge/releases/download/v0.125.1/forge-x86_64-unknown-linux-gnu";
      hash = "sha256-1hh18yYhhaurAxaw1oS1g4LGMtgiZkd0VxN47Ptm2aM=";
    };
    aarch64-linux = {
      url = "https://github.com/antinomyhq/forge/releases/download/v0.125.1/forge-aarch64-unknown-linux-gnu";
      hash = "sha256-eeSaFxPj/N9zO950lkW+TzEnHvkN2ilnQeQGfPCw5UM=";
    };
    x86_64-darwin = {
      url = "https://github.com/antinomyhq/forge/releases/download/v0.125.1/forge-x86_64-apple-darwin";
      hash = "sha256-PeoL00FsGmnV0F4E+TWcYNEU8gfnakhZskNlGhySnkw=";
    };
    aarch64-darwin = {
      url = "https://github.com/antinomyhq/forge/releases/download/v0.125.1/forge-aarch64-apple-darwin";
      hash = "sha256-T4G1txqbUQPG6q0QWSsTunvXbsB8tT2AgkG2N7A81pY=";
    };
  };
in
stdenv.mkDerivation rec {
  pname = "forge";
  version = "0.125.1";

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
