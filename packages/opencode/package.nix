{
  lib,
  stdenv,
  fetchzip,
  autoPatchelfHook,
}:

let
  version = "0.6.5";

  sources = {
    x86_64-linux = {
      url = "https://github.com/sst/opencode/releases/download/v${version}/opencode-linux-x64.zip";
      sha256 = "sha256-KBT0o6d3NG3KZAtqmB4QK7h1zMbO88x9SFVsoOi6S3Q=";
    };
    aarch64-linux = {
      url = "https://github.com/sst/opencode/releases/download/v${version}/opencode-linux-arm64.zip";
      sha256 = "sha256-90h65LYGR+7+pSF+IdkDT46Lkij79POMJAaKMm8+WYg=";
    };
    x86_64-darwin = {
      url = "https://github.com/sst/opencode/releases/download/v${version}/opencode-darwin-x64.zip";
      sha256 = "sha256-hQC8sfkKArF1gpUjmNCb6nUSTpwWeMUQ1VIVXEpQW/8=";
    };
    aarch64-darwin = {
      url = "https://github.com/sst/opencode/releases/download/v${version}/opencode-darwin-arm64.zip";
      sha256 = "sha256-aU7kOuK7cV1AtouHQ5/HrE2n0PsSW3zW7FgguTDjcsc=";
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
