{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  autoPatchelfHook,
  zlib,
}:

let
  version = "2.0.54";

  sources = {
    x86_64-linux = {
      url = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases/${version}/linux-x64/claude";
      hash = "sha256-V0Gp40582JBiCFrOqsvoxpSXzrzFVS57jna8bjRauYI=";
    };
    aarch64-linux = {
      url = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases/${version}/linux-arm64/claude";
      hash = "sha256-Rx+iUk3+k4NqRsVg6cZCIO1d4AoN9KlSFYJoE+h42Ng=";
    };
    x86_64-darwin = {
      url = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases/${version}/darwin-x64/claude";
      hash = "sha256-lRaE23o786zjO0SXX9AKmxRHMm39r4SQp9+2QaAQ1aY=";
    };
    aarch64-darwin = {
      url = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases/${version}/darwin-arm64/claude";
      hash = "sha256-/X5mn786frVbEgUlnMTkFwOKVlIZ55xnoj8VlL2NhxY=";
    };
  };

  source =
    sources.${stdenv.hostPlatform.system}
      or (throw "Unsupported system: ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "claude-code";
  inherit version;

  src = fetchurl {
    inherit (source) url hash;
  };

  dontUnpack = true;

  nativeBuildInputs = [
    makeWrapper
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    stdenv.cc.cc.lib
    zlib
  ];

  dontStrip = true; # do not mess with the bun runtime

  installPhase = ''
    runHook preInstall

    install -Dm755 $src $out/bin/claude

    runHook postInstall
  '';

  # Disable auto-updates and telemetry by wrapping the binary
  postFixup = ''
    wrapProgram $out/bin/claude \
      --set DISABLE_AUTOUPDATER 1 \
      --set CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC 1 \
      --set DISABLE_NON_ESSENTIAL_MODEL_CALLS 1 \
      --set DISABLE_TELEMETRY 1
  '';

  meta = with lib; {
    description = "Agentic coding tool that lives in your terminal, understands your codebase, and helps you code faster";
    homepage = "https://claude.ai/code";
    changelog = "https://github.com/anthropics/claude-code/releases";
    license = licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    maintainers = with maintainers; [
      malo
      omarjatoi
    ];
    mainProgram = "claude";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
  };
}
