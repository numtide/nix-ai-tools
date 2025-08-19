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
      url = "https://github.com/antinomyhq/forge/releases/download/v0.109.1/forge-x86_64-unknown-linux-gnu";
      hash = "sha256-B26wzxv2uElUS+Lq+ZdfnplL8R5Rzp9dXHjK9IkKTlE=";
    };
    aarch64-linux = {
      url = "https://github.com/antinomyhq/forge/releases/download/v0.109.1/forge-aarch64-unknown-linux-gnu";
      hash = "sha256-6zRUuPFJrIrwgufUXudl2P3Fd9wcy7ltNVxSgFMAdZ4=";
    };
    x86_64-darwin = {
      url = "https://github.com/antinomyhq/forge/releases/download/v0.109.1/forge-x86_64-apple-darwin";
      hash = "sha256-kupVwrbc3NPOyVAGuXIRm2u3fxiuT3YHbeT3Bnu6Fx0=";
    };
    aarch64-darwin = {
      url = "https://github.com/antinomyhq/forge/releases/download/v0.109.1/forge-aarch64-apple-darwin";
      hash = "sha256-hI7MEj5jK0s/YYoTTSP4Y4rR8SLwSbnitfy3yL9rzDw=";
    };
  };
in
stdenv.mkDerivation rec {
  pname = "forge";
  version = "0.109.1";

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
