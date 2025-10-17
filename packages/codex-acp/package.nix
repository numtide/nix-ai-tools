{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  gcc-unwrapped,
  openssl,
}:

let
  version = "0.2.9";
  sources = {
    x86_64-linux = {
      url = "https://github.com/zed-industries/codex-acp/releases/download/v${version}/codex-acp-${version}-x86_64-unknown-linux-gnu.tar.gz";
      hash = "sha256-3vf81sw3cRxyzOe6lCp6mABnfzwDisWkVRztEPs353U=";
    };
    aarch64-linux = {
      url = "https://github.com/zed-industries/codex-acp/releases/download/v${version}/codex-acp-${version}-aarch64-unknown-linux-gnu.tar.gz";
      hash = "sha256-xCtKcmX32EzrZp+dQp7WeDBH9GJ4CW+vM0urRMZIqaQ=";
    };
    x86_64-darwin = {
      url = "https://github.com/zed-industries/codex-acp/releases/download/v${version}/codex-acp-${version}-x86_64-apple-darwin.tar.gz";
      hash = "sha256-p1Wc9Em/lt/jYhW/XaiOX1Qx1xSJoOKtm4SnVW2dK2U=";
    };
    aarch64-darwin = {
      url = "https://github.com/zed-industries/codex-acp/releases/download/v${version}/codex-acp-${version}-aarch64-apple-darwin.tar.gz";
      hash = "sha256-SvzkWnBJ4k/B1f/rnQgCYJOy+Do+Cj7U2zmxCnr+wvU=";
    };
  };
  source =
    sources.${stdenv.hostPlatform.system}
      or (throw "Unsupported system: ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "codex-acp";
  inherit version;

  src = fetchurl {
    inherit (source) url hash;
  };

  nativeBuildInputs = lib.optionals stdenv.isLinux [ autoPatchelfHook ];

  buildInputs = lib.optionals stdenv.isLinux [
    gcc-unwrapped.lib
    openssl
  ];

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    install -Dm755 codex-acp $out/bin/codex-acp

    runHook postInstall
  '';

  meta = with lib; {
    description = "An ACP-compatible coding agent powered by Codex";
    homepage = "https://github.com/zed-industries/codex-acp";
    changelog = "https://github.com/zed-industries/codex-acp/releases/tag/v${version}";
    downloadPage = "https://github.com/zed-industries/codex-acp/releases";
    license = licenses.asl20;
    maintainers = with maintainers; [ ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    mainProgram = "codex-acp";
  };
}
