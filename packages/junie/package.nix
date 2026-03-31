{
  lib,
  stdenv,
  fetchurl,
  unzip,
  versionCheckHook,
}:

let
  pname = "junie";
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version hashes;

  platformMap = {
    x86_64-linux = "linux-amd64";
    aarch64-linux = "linux-aarch64";
    x86_64-darwin = "macos-amd64";
    aarch64-darwin = "macos-aarch64";
  };

  platform = stdenv.hostPlatform.system;
  platformSuffix = platformMap.${platform} or (throw "Unsupported system: ${platform}");
in
stdenv.mkDerivation {
  inherit pname version;

  src = fetchurl {
    url = "https://github.com/JetBrains/junie/releases/download/${version}/junie-release-${version}-${platformSuffix}.zip";
    hash = hashes.${platform};
  };

  nativeBuildInputs = [ unzip ];

  unpackPhase = ''
    runHook preUnpack
    unzip $src
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/lib
    cp -r junie-app/bin/. $out/bin/
    cp -r junie-app/lib/. $out/lib/
    runHook postInstall
  '';

  doInstallCheck = true;
  # the version check fails
  dontVersionCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
  ];

  passthru.category = "AI Coding Agents";

  meta = with lib; {
    description = "Junie, JetBrains AI coding agent CLI";
    homepage = "https://github.com/JetBrains/junie";
    changelog = "https://github.com/JetBrains/junie/releases/tag/${version}";
    license = licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    mainProgram = "junie";
  };
}
