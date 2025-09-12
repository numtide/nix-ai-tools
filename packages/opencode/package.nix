{
  lib,
  stdenv,
  fetchzip,
  autoPatchelfHook,
}:

let
  version = "0.7.3";

  sources = {
    x86_64-linux = {
      url = "https://github.com/sst/opencode/releases/download/v${version}/opencode-linux-x64.zip";
      sha256 = "sha256-dW1aIK2JIkdEhykFDfEJ0SozmG/dhntyntULvoFmz24=";
    };
    aarch64-linux = {
      url = "https://github.com/sst/opencode/releases/download/v${version}/opencode-linux-arm64.zip";
      sha256 = "sha256-aJ6vmBUv9IPxK98Y968PwB+/r1PZ2Wejs1t/bQQukSo=";
    };
    x86_64-darwin = {
      url = "https://github.com/sst/opencode/releases/download/v${version}/opencode-darwin-x64.zip";
      sha256 = "sha256-Qk3acZFxb87UFmll9M1dKvyPQXYHZLAENLJ6tgMPTOE=";
    };
    aarch64-darwin = {
      url = "https://github.com/sst/opencode/releases/download/v${version}/opencode-darwin-arm64.zip";
      sha256 = "sha256-pqPP7ZwcydYHkuqsazb3Zhw9hO+dXnk/3Ll4VGBH5Hw=";
    };
  };

  source =
    sources.${stdenv.hostPlatform.system}
      or (throw "Unsupported system: ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "opencode";
  inherit version;

  src = fetchzip {
    url = source.url;
    sha256 = source.sha256;
    stripRoot = false;
  };

  nativeBuildInputs = lib.optionals stdenv.isLinux [
    autoPatchelfHook
  ];

  buildInputs = lib.optionals stdenv.isLinux [
    stdenv.cc.cc.lib
  ];

  dontBuild = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall


    mkdir -p $out/bin
    cp opencode $out/bin/
    chmod +x $out/bin/opencode

    runHook postInstall
  '';

  postFixup = lib.optionalString stdenv.isLinux ''
    patchelf --add-needed "$(patchelf --print-soname ${stdenv.cc.cc.lib}/lib/libstdc++.so)" $out/bin/opencode
  '';

  passthru = {
    updateScript = ./update.sh;
  };

  meta = with lib; {
    description = "AI coding agent, built for the terminal";
    homepage = "https://github.com/sst/opencode";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    mainProgram = "opencode";
  };
}
