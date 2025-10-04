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
      url = "https://github.com/antinomyhq/forge/releases/download/v0.122.2/forge-x86_64-unknown-linux-gnu";
      hash = "sha256-i+ifjghsou2iSdllRUabEYnMpk3pS4wsDLUZ5C3mnaw=";
    };
    aarch64-linux = {
      url = "https://github.com/antinomyhq/forge/releases/download/v0.122.2/forge-aarch64-unknown-linux-gnu";
      hash = "sha256-0XvwivOeoR4RW/fyyeDI3JeL25OQzd7D3PbAljGxFXo=";
    };
    x86_64-darwin = {
      url = "https://github.com/antinomyhq/forge/releases/download/v0.122.2/forge-x86_64-apple-darwin";
      hash = "sha256-zPhx9OESJVb+HfUqlncOueXqi+UgVTtvn2Aoh9kkEHo=";
    };
    aarch64-darwin = {
      url = "https://github.com/antinomyhq/forge/releases/download/v0.122.2/forge-aarch64-apple-darwin";
      hash = "sha256-1Ppd45WMzU28TLn5M79Zd0JaeJpvga5Vek+MSxz0Rdw=";
    };
  };
in
stdenv.mkDerivation rec {
  pname = "forge";
  version = "0.122.2";

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
