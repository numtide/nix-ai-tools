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
      url = "https://github.com/antinomyhq/forge/releases/download/v0.114.4/forge-x86_64-unknown-linux-gnu";
      hash = "sha256-pzk+hykEQ+RiNAY17rvhxxjXJKYtgFqx1WgOi0JOdQw=";
    };
    aarch64-linux = {
      url = "https://github.com/antinomyhq/forge/releases/download/v0.114.4/forge-aarch64-unknown-linux-gnu";
      hash = "sha256-EQCSLGS7zxExekXaABG/GJwQ75nAjCmu859lI6t8puQ=";
    };
    x86_64-darwin = {
      url = "https://github.com/antinomyhq/forge/releases/download/v0.114.4/forge-x86_64-apple-darwin";
      hash = "sha256-ND89UfS4ikO47y3GUe+eTnafg1Q8adH7WaUBUfWMA+k=";
    };
    aarch64-darwin = {
      url = "https://github.com/antinomyhq/forge/releases/download/v0.114.4/forge-aarch64-apple-darwin";
      hash = "sha256-QDAv8z56r3MIlSYrwv/sM19RzoFcxRXj851mjMAgtW4=";
    };
  };
in
stdenv.mkDerivation rec {
  pname = "forge";
  version = "0.114.4";

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
