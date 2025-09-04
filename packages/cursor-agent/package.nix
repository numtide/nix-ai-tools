{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  autoPatchelfHook,
}:

let
  pname = "cursor-agent";
  version = "2025.09.03-e077a54";

  srcs = {
    x86_64-linux = fetchurl {
      url = "https://downloads.cursor.com/lab/${version}/linux/x64/agent-cli-package.tar.gz";
      hash = "sha256-Yn+UJQiGuzCVe046cS4fPZCFc1/9wZomVAYigY6rb1w=";
    };
    aarch64-linux = fetchurl {
      url = "https://downloads.cursor.com/lab/${version}/linux/arm64/agent-cli-package.tar.gz";
      hash = "sha256-3nvIWyVAXVyTs/nSaZDkDKOp4CLiBQFMZIgIjnUq+Rw=";
    };
    x86_64-darwin = fetchurl {
      url = "https://downloads.cursor.com/lab/${version}/darwin/x64/agent-cli-package.tar.gz";
      hash = "sha256-LlmpFyp0v28nOWdVs7DwMjf5lJd/HKSeMsbBuwVCuNw=";
    };
    aarch64-darwin = fetchurl {
      url = "https://downloads.cursor.com/lab/${version}/darwin/arm64/agent-cli-package.tar.gz";
      hash = "sha256-nxGQKq3433yA8aAHz1iBtpV5s526KqzBQQaYQatOtqI=";
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
