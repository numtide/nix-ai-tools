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
      url = "https://github.com/antinomyhq/forge/releases/download/v0.110.0/forge-x86_64-unknown-linux-gnu";
      hash = "sha256-B2+o2i98d0VIzTxIhZxY++lY2xaFiIuJ7WlQPh/OcyI=";
    };
    aarch64-linux = {
      url = "https://github.com/antinomyhq/forge/releases/download/v0.110.0/forge-aarch64-unknown-linux-gnu";
      hash = "sha256-IO+ecIF7R4e+ZloShVpTViENcgi6lv+v9fKhwmnk084=";
    };
    x86_64-darwin = {
      url = "https://github.com/antinomyhq/forge/releases/download/v0.110.0/forge-x86_64-apple-darwin";
      hash = "sha256-65Jb9mENRQGmNfcAdeoYjYtC7BUAhf8UOfu0sZBglIM=";
    };
    aarch64-darwin = {
      url = "https://github.com/antinomyhq/forge/releases/download/v0.110.0/forge-aarch64-apple-darwin";
      hash = "sha256-Lc5z2e8Jg8FsIUMfcYUH8H/PHO8zdDMoYOCCvxhHr34=";
    };
  };
in
stdenv.mkDerivation rec {
  pname = "forge";
  version = "0.110.0";

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
