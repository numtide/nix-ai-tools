{
  lib,
  stdenv,
  fetchurl,
  wrapBuddy,
  versionCheckHook,
  versionCheckHomeHook,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version platforms;

  platform = stdenv.hostPlatform.system;
  src = platforms.${platform} or (throw "Unsupported system: ${platform}");
in
stdenv.mkDerivation {
  pname = "qoder-cli";
  inherit version;

  src = fetchurl {
    inherit (src) url hash;
  };

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [ wrapBuddy ];

  sourceRoot = ".";

  dontStrip = true; # do not mess with the bun runtime

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
