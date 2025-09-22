{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  gcc-unwrapped,
}:

let
  version = "0.11.0";
  sources = {
    x86_64-linux = {
      url = "https://github.com/wandb/catnip/releases/download/v${version}/catnip_${version}_linux_amd64.tar.gz";
      hash = "sha256-WUWuH5/KdkD26XgHE0h2xrYcaXkFXTGMoXiblTpFh64=";
    };
    aarch64-linux = {
      url = "https://github.com/wandb/catnip/releases/download/v${version}/catnip_${version}_linux_arm64.tar.gz";
      hash = "sha256-IWizPtw+dxj6PKH5HKTUuAPt8jRrHdW03TqXIZ0Z9ts=";
    };
    x86_64-darwin = {
      url = "https://github.com/wandb/catnip/releases/download/v${version}/catnip_${version}_darwin_amd64.tar.gz";
      hash = "sha256-E8RgkdHudf2R+ocz5QAD4j6taTVekNlWi0dzBy5kQ3A=";
    };
    aarch64-darwin = {
      url = "https://github.com/wandb/catnip/releases/download/v${version}/catnip_${version}_darwin_arm64.tar.gz";
      hash = "sha256-XALCqnp4ohjlXAQtwZGYeeAuBcWlvbLSg+Afbieq6HU=";
    };
  };
  source =
    sources.${stdenv.hostPlatform.system}
      or (throw "Unsupported system: ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "catnip";
  inherit version;

  src = fetchurl {
    inherit (source) url hash;
  };

  nativeBuildInputs = lib.optionals stdenv.isLinux [ autoPatchelfHook ];

  buildInputs = lib.optionals stdenv.isLinux [
    gcc-unwrapped.lib
  ];

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    ${
      if stdenv.isDarwin then
        ''
          mkdir -p $out/Applications
          cp -r Catnip.app $out/Applications/
          mkdir -p $out/bin
          ln -s $out/Applications/Catnip.app/Contents/MacOS/catnip $out/bin/catnip
        ''
      else
        ''
          install -Dm755 catnip $out/bin/catnip
        ''
    }

    runHook postInstall
  '';

  passthru.updateScript = ./update-script.sh;

  meta = with lib; {
    description = "Developer environment that's like catnip for agentic programming";
    homepage = "https://github.com/wandb/catnip";
    changelog = "https://github.com/wandb/catnip/releases/tag/v${version}";
    downloadPage = "https://github.com/wandb/catnip/releases";
    license = licenses.asl20;
    maintainers = with maintainers; [ ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    mainProgram = "catnip";
  };
}
