{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  wrapBuddy,
  versionCheckHook,
  versionCheckHomeHook,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version hashes;

  platformMap = {
    x86_64-linux = "linux-x64";
    aarch64-linux = "linux-arm64";
    x86_64-darwin = "darwin-x64";
    aarch64-darwin = "darwin-arm64";
  };

  platform = stdenv.hostPlatform.system;
  npmPlatform = platformMap.${platform} or (throw "Unsupported system: ${platform}");
in
stdenv.mkDerivation {
  pname = "kilocode-cli";
  inherit version;

  src = fetchurl {
    url = "https://registry.npmjs.org/@kilocode/cli-${npmPlatform}/-/cli-${npmPlatform}-${version}.tgz";
    hash = hashes.${platform};
  };

  sourceRoot = "package";

  nativeBuildInputs = [ makeWrapper ] ++ lib.optionals stdenv.hostPlatform.isLinux [ wrapBuddy ];

  dontBuild = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 bin/kilo $out/bin/kilocode

    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];
  versionCheckProgramArg = "--version";

  passthru.category = "AI Coding Agents";

  meta = {
    description = "The open-source AI coding agent. Now available in your terminal.";
    homepage = "https://kilocode.ai/cli";
    downloadPage = "https://www.npmjs.com/package/@kilocode/cli";
    license = lib.licenses.asl20;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "kilocode";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
  };
}
