{
  lib,
  stdenvNoCC,
  fetchurl,
  makeWrapper,
  autoPatchelfHook,
  stdenv,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version hashes;

  platformMap = {
    x86_64-linux = "omp-linux-x64";
    aarch64-linux = "omp-linux-arm64";
    x86_64-darwin = "omp-darwin-x64";
    aarch64-darwin = "omp-darwin-arm64";
  };

  platform = stdenvNoCC.hostPlatform.system;
  platformBinary = platformMap.${platform} or (throw "Unsupported system: ${platform}");
in
stdenvNoCC.mkDerivation {
  pname = "omp";
  inherit version;

  src = fetchurl {
    url = "https://github.com/can1357/oh-my-pi/releases/download/v${version}/${platformBinary}";
    hash = hashes.${platform};
  };

  dontUnpack = true;
  dontStrip = true;

  nativeBuildInputs = [
    makeWrapper
  ]
  ++ lib.optionals stdenvNoCC.hostPlatform.isLinux [
    autoPatchelfHook
  ];

  buildInputs = lib.optionals stdenvNoCC.hostPlatform.isLinux [
    stdenv.cc.cc.lib
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    cp $src $out/bin/omp
    chmod +x $out/bin/omp

    wrapProgram $out/bin/omp \
      --set PI_SKIP_VERSION_CHECK 1

    runHook postInstall
  '';

  passthru.category = "AI Coding Agents";

  meta = with lib; {
    description = "A terminal-based coding agent with multi-model support (binary release)";
    homepage = "https://github.com/can1357/oh-my-pi";
    changelog = "https://github.com/can1357/oh-my-pi/releases/tag/v${version}";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    maintainers = with maintainers; [ aldoborrero ];
    platforms = builtins.attrNames platformMap;
    mainProgram = "omp";
  };
}
