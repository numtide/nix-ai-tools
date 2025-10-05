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
      url = "https://github.com/antinomyhq/forge/releases/download/v0.123.1/forge-x86_64-unknown-linux-gnu";
      hash = "sha256-ZSCXak3w5yPqQKEoWyv/N6T5VBpf/6TmHtB7G8LUaTQ=";
    };
    aarch64-linux = {
      url = "https://github.com/antinomyhq/forge/releases/download/v0.123.1/forge-aarch64-unknown-linux-gnu";
      hash = "sha256-0OkAwZJkSkOjb2irXfxafod6lb4DS65Xo02QawOArQo=";
    };
    x86_64-darwin = {
      url = "https://github.com/antinomyhq/forge/releases/download/v0.123.1/forge-x86_64-apple-darwin";
      hash = "sha256-3o/v8QwMXs8hQ5GTBTqHvl7q4H1AOngN9PuBzw0tC7U=";
    };
    aarch64-darwin = {
      url = "https://github.com/antinomyhq/forge/releases/download/v0.123.1/forge-aarch64-apple-darwin";
      hash = "sha256-UdpjOfX4IQMhAL4PWknbXhw/ZFuxc2TM22/ZD49zVPE=";
    };
  };
in
stdenv.mkDerivation rec {
  pname = "forge";
  version = "0.123.1";

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
