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
      url = "https://github.com/antinomyhq/forge/releases/download/v0.125.0/forge-x86_64-unknown-linux-gnu";
      hash = "sha256-F5H2xzkyLxDL7U1ZHE/Xq10hmRwDk8iMLDRWE+zMdS0=";
    };
    aarch64-linux = {
      url = "https://github.com/antinomyhq/forge/releases/download/v0.125.0/forge-aarch64-unknown-linux-gnu";
      hash = "sha256-d93q5+/I9CVIYAArU+HaBOKAcy7GRb74tFaV4hXuZb8=";
    };
    x86_64-darwin = {
      url = "https://github.com/antinomyhq/forge/releases/download/v0.125.0/forge-x86_64-apple-darwin";
      hash = "sha256-vbEGVQA6imTZDLF+kaS8o7F/Se2OlT2UHXpOyfDtwZQ=";
    };
    aarch64-darwin = {
      url = "https://github.com/antinomyhq/forge/releases/download/v0.125.0/forge-aarch64-apple-darwin";
      hash = "sha256-I5bXt6SDFVfGI5m4V8ZAmRUjRWeNo6q4a8KETbbI9jw=";
    };
  };
in
stdenv.mkDerivation rec {
  pname = "forge";
  version = "0.125.0";

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
