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
      url = "https://github.com/antinomyhq/forge/releases/download/v0.112.0/forge-x86_64-unknown-linux-gnu";
      hash = "sha256-01Af2bhv9+NBpEdj3ki0LsbcmoiZdLn6vIybaL4xW10=";
    };
    aarch64-linux = {
      url = "https://github.com/antinomyhq/forge/releases/download/v0.112.0/forge-aarch64-unknown-linux-gnu";
      hash = "sha256-joj4fFolDfdVgUC33YgGjSw1FF2z3og5dQjg3D9m4w4=";
    };
    x86_64-darwin = {
      url = "https://github.com/antinomyhq/forge/releases/download/v0.112.0/forge-x86_64-apple-darwin";
      hash = "sha256-Fs8HBabfvZl0RX+IMBSVwZVfC1Pog5PC91ljRYASfp4=";
    };
    aarch64-darwin = {
      url = "https://github.com/antinomyhq/forge/releases/download/v0.112.0/forge-aarch64-apple-darwin";
      hash = "sha256-h7C620vA7GWcF6NKOrBZiJ8IhAf3TQxSw2uvnrVgTE4=";
    };
  };
in
stdenv.mkDerivation rec {
  pname = "forge";
  version = "0.112.0";

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
