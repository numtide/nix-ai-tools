{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  autoPatchelfHook,
  gcc-unwrapped,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version hashes;

  bucket = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases";

  platformMap = {
    x86_64-linux = "linux-x64";
    aarch64-linux = "linux-arm64";
    x86_64-darwin = "darwin-x64";
    aarch64-darwin = "darwin-arm64";
  };

  platform = stdenv.hostPlatform.system;
  platformPath = platformMap.${platform} or (throw "Unsupported system: ${platform}");
in
stdenv.mkDerivation {
  pname = "claude-code-native";
  inherit version;

  src = fetchurl {
    url = "${bucket}/${version}/${platformPath}/claude";
    hash = hashes.${platform};
  };

  nativeBuildInputs = [
    makeWrapper
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [
    autoPatchelfHook
  ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    gcc-unwrapped.lib
  ];

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 $src $out/bin/claude

    # Disable auto-updates and telemetry by wrapping the binary
    wrapProgram $out/bin/claude \
      --set DISABLE_AUTOUPDATER 1 \
      --set CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC 1 \
      --set DISABLE_NON_ESSENTIAL_MODEL_CALLS 1 \
      --set DISABLE_TELEMETRY 1 \
      --unset DEV

    runHook postInstall
  '';

  meta = with lib; {
    description = "Agentic coding tool that lives in your terminal, understands your codebase, and helps you code faster (native binary)";
    homepage = "https://github.com/anthropics/claude-code";
    changelog = "https://github.com/anthropics/claude-code/releases";
    license = licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    maintainers = with maintainers; [ ];
    mainProgram = "claude";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
  };
}
