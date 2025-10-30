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
      url = "https://github.com/antinomyhq/forge/releases/download/v1.2.0/forge-x86_64-unknown-linux-gnu";
      hash = "sha256-c2rUtTmKOEeG70t9OFyEoCk9uHPeTEXQUmNvX7QCDgo=";
    };
    aarch64-linux = {
      url = "https://github.com/antinomyhq/forge/releases/download/v1.2.0/forge-aarch64-unknown-linux-gnu";
      hash = "sha256-gYa3r2xenX8k5haa4gxI1JtJD9gcz4wcUuLVMx6zTDo=";
    };
    x86_64-darwin = {
      url = "https://github.com/antinomyhq/forge/releases/download/v1.2.0/forge-x86_64-apple-darwin";
      hash = "sha256-CKOhYk9Q9eaHdk+L8tQXSuHDQcOhYGZ3Dk3KAuE5QeE=";
    };
    aarch64-darwin = {
      url = "https://github.com/antinomyhq/forge/releases/download/v1.2.0/forge-aarch64-apple-darwin";
      hash = "sha256-mB9xn6M46dbSmLVGyGoQz0B2uqjEkpQ4EmTvqult1tU=";
    };
  };
in
stdenv.mkDerivation rec {
  pname = "forge";
  version = "1.2.0";

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
