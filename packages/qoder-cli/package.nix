{
  lib,
  stdenv,
  fetchurl,
  unzip,
  wrapBuddy,
  gcc-unwrapped,
  versionCheckHook,
  versionCheckHomeHook,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version hashes;

  platformMap = {
    x86_64-linux = "linux_amd64.tar.gz";
    aarch64-linux = "linux_arm64.tar.gz";
    x86_64-darwin = "darwin_amd64.zip";
    aarch64-darwin = "darwin_arm64.zip";
  };

  platform = stdenv.hostPlatform.system;
  platformSuffix = platformMap.${platform} or (throw "Unsupported system: ${platform}");
in
stdenv.mkDerivation {
  pname = "qoder-cli";
  inherit version;

  src = fetchurl {
    url = "https://download.qoder.com/qodercli/releases/${version}/qodercli_${version}_${platformSuffix}";
    hash = hashes.${platform};
  };

  nativeBuildInputs =
    lib.optionals stdenv.isDarwin [ unzip ] ++ lib.optionals stdenv.isLinux [ wrapBuddy ];

  buildInputs = lib.optionals stdenv.isLinux [ gcc-unwrapped.lib ];

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    install -Dm755 qodercli $out/bin/qodercli

    runHook postInstall
  '';

  doInstallCheck = true;

  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];

  passthru.category = "AI Coding Agents";

  meta = with lib; {
    description = "Qoder AI CLI tool - Terminal-based AI assistant for code development";
    homepage = "https://qoder.com";
    changelog = "https://qoder.com/changelog";
    downloadPage = "https://qoder.com/download";
    license = licenses.unfree;
    maintainers = with maintainers; [ ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    mainProgram = "qodercli";
  };
}
