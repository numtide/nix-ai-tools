{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  wrapBuddy,
  fd,
  ripgrep,
  versionCheckHook,
  versionCheckHomeHook,
}:

let
  pname = "pi";
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version hashes;

  # Map nix system to release asset name
  platformMap = {
    x86_64-linux = "pi-linux-x64.tar.gz";
    aarch64-linux = "pi-linux-arm64.tar.gz";
    x86_64-darwin = "pi-darwin-x64.tar.gz";
    aarch64-darwin = "pi-darwin-arm64.tar.gz";
  };

  platform = stdenv.hostPlatform.system;
  platformInfo = platformMap.${platform} or (throw "Unsupported system: ${platform}");

  src = fetchurl {
    url = "https://github.com/badlogic/pi-mono/releases/download/v${version}/${platformInfo}";
    hash = hashes.${platform};
  };
in
stdenv.mkDerivation {
  inherit pname version src;

  nativeBuildInputs = [
    makeWrapper
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [
    wrapBuddy
  ];

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHomeHook
    versionCheckHook
  ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    stdenv.cc.cc.lib
  ];

  dontConfigure = true;
  dontBuild = true;
  # otherwise strip will remove the compressed typescript code
  dontStrip = true;

  unpackPhase = ''
    runHook preUnpack

    tar -xzf $src

    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin/

    cp -r theme $out/bin/
    cp package.json $out/bin/

    install -m755 pi $out/bin/

    # Wrap to add fd and ripgrep to PATH
    wrapProgram $out/bin/pi \
      --prefix PATH : ${
        lib.makeBinPath [
          fd
          ripgrep
        ]
      }

    runHook postInstall
  '';

  meta = {
    description = "A terminal-based coding agent with multi-model support, mid-session model switching, and a simple CLI for headless coding tasks.";
    homepage = "https://github.com/badlogic/pi-mono";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    mainProgram = "pi";
  };
}
