{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  autoPatchelfHook,
}:

let
  pname = "cursor-agent";
  version = "2025.08.09-d8191f3";

  srcs = {
    x86_64-linux = fetchurl {
      url = "https://downloads.cursor.com/lab/${version}/linux/x64/agent-cli-package.tar.gz";
      hash = "sha256-sLI6D0A9GBqIJkC4i83Z9nBwk5TMQTclK1Hnkg+h8ds=";
    };
    aarch64-linux = fetchurl {
      url = "https://downloads.cursor.com/lab/${version}/linux/arm64/agent-cli-package.tar.gz";
      hash = "sha256-6ei07gyIHgikbKFvtAF7sRQ2/f/2slJdkuMOAlvIDPA=";
    };
    x86_64-darwin = fetchurl {
      url = "https://downloads.cursor.com/lab/${version}/darwin/x64/agent-cli-package.tar.gz";
      hash = "sha256-zuhYmRAb2v7BUko8dX+i8kxV7C5E88G/IQNX72PWHdI=";
    };
    aarch64-darwin = fetchurl {
      url = "https://downloads.cursor.com/lab/${version}/darwin/arm64/agent-cli-package.tar.gz";
      hash = "sha256-vz3i8QXJpeHRJ3bZHh0wWK/CCsNXFsk2p08pzkzyPyg=";
    };
  };

  src =
    srcs.${stdenv.hostPlatform.system} or (throw "Unsupported system: ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation rec {
  inherit pname version src;

  nativeBuildInputs = [
    makeWrapper
  ]
  ++ lib.optionals stdenv.isLinux [
    autoPatchelfHook
  ];

  buildInputs = lib.optionals stdenv.isLinux [
    stdenv.cc.cc.lib
  ];

  unpackPhase = ''
    runHook preUnpack
    tar -xzf $src
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    # Copy the dist-package contents
    mkdir -p $out
    cp -r dist-package/* $out/

    # Ensure binaries are executable
    chmod +x $out/cursor-agent
    chmod +x $out/node
    chmod +x $out/rg

    # Create a wrapper in bin directory
    mkdir -p $out/bin
    makeWrapper $out/cursor-agent $out/bin/cursor-agent \
      --prefix PATH : $out

    runHook postInstall
  '';

  meta = with lib; {
    description = "Cursor Agent - CLI tool for Cursor AI code editor";
    homepage = "https://cursor.com/";
    license = licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    maintainers = with maintainers; [ ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    mainProgram = "cursor-agent";
  };
}
