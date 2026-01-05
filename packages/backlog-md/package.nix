{
  lib,
  stdenv,
  fetchurl,
  wrapBuddy,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version hashes;

  platformMap = {
    x86_64-linux = "linux-x64-baseline";
    aarch64-linux = "linux-arm64";
    x86_64-darwin = "darwin-x64";
    aarch64-darwin = "darwin-arm64";
  };

  platform = stdenv.hostPlatform.system;
  platformSuffix = platformMap.${platform} or (throw "Unsupported system: ${platform}");
in
stdenv.mkDerivation {
  pname = "backlog-md";
  inherit version;

  src = fetchurl {
    url = "https://github.com/MrLesk/Backlog.md/releases/download/v${version}/backlog-bun-${platformSuffix}";
    hash = hashes.${platform};
  };

  dontUnpack = true;

  nativeBuildInputs = lib.optionals stdenv.isLinux [ wrapBuddy ];

  # Don't strip the binary - bun compile embeds the JavaScript program
  # in the executable and stripping would remove it
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    cp $src $out/bin/backlog
    chmod +x $out/bin/backlog

    runHook postInstall
  '';

  meta = with lib; {
    description = "Backlog.md - A tool for managing project collaboration between humans and AI Agents in a git ecosystem";
    homepage = "https://github.com/MrLesk/Backlog.md";
    changelog = "https://github.com/MrLesk/Backlog.md/releases";
    license = licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    maintainers = with maintainers; [ ];
    mainProgram = "backlog";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
  };
}
