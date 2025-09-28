{
  lib,
  stdenv,
  fetchurl,
  unzip,
  autoPatchelfHook,
}:

let
  version = "0.3.2";

  sources = {
    x86_64-linux = {
      url = "https://cli.coderabbit.ai/releases/${version}/coderabbit-linux-x64.zip";
      hash = "sha256-u7acQ5XK2mM1cATqHqI3Xs9MhKHuVBZz1SV6URHKUdk=";
    };
    aarch64-linux = {
      url = "https://cli.coderabbit.ai/releases/${version}/coderabbit-linux-arm64.zip";
      hash = "sha256-gZ+4MKZwPIeMjooHondI+50lVPMf7xybe3SvIGnnnSM=";
    };
    x86_64-darwin = {
      url = "https://cli.coderabbit.ai/releases/${version}/coderabbit-darwin-x64.zip";
      hash = "sha256-abWiFK5lu2trNNz1CQxgnbXJi7mqbgTVPLbxMy5Sris=";
    };
    aarch64-darwin = {
      url = "https://cli.coderabbit.ai/releases/${version}/coderabbit-darwin-arm64.zip";
      hash = "sha256-DGyTSzF/Pn/EkRvZ9BJ5yvZtRL+q1JUoWJzzpAF9u6M=";
    };
  };

  source =
    sources.${stdenv.hostPlatform.system}
      or (throw "Unsupported system: ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation rec {
  pname = "coderabbit-cli";
  inherit version;

  src = fetchurl {
    inherit (source) url hash;
  };

  nativeBuildInputs = [ unzip ] ++ lib.optionals stdenv.isLinux [ autoPatchelfHook ];

  unpackPhase = ''
    unzip $src
  '';

  dontStrip = true; # to no mess with the bun runtime

  installPhase = ''
    runHook preInstall

    install -Dm755 coderabbit $out/bin/coderabbit
    ln -s $out/bin/coderabbit $out/bin/cr

    runHook postInstall
  '';

  meta = with lib; {
    description = "AI-powered code review CLI tool";
    homepage = "https://coderabbit.ai";
    license = licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    mainProgram = "coderabbit";
  };
}
