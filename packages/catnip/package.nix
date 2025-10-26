{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  gcc-unwrapped,
}:

let
  version = "0.11.2";
  sources = {
    x86_64-linux = {
      url = "https://github.com/wandb/catnip/releases/download/v${version}/catnip_${version}_linux_amd64.tar.gz";
      hash = "sha256-JonKUsXZMALHadPTQYKkBVWc/C8bKlTzOSCSPq4tRik=";
    };
    aarch64-linux = {
      url = "https://github.com/wandb/catnip/releases/download/v${version}/catnip_${version}_linux_arm64.tar.gz";
      hash = "sha256-2rlFn1d72IpZaLN7wkNmehHcTzUiNTgd9YQZW73moaE=";
    };
    x86_64-darwin = {
      url = "https://github.com/wandb/catnip/releases/download/v${version}/catnip_${version}_darwin_amd64.tar.gz";
      hash = "sha256-jtNRAHDgtJ5MK6iRjjr7TQ3ra0VKvNMpVJuo1d/51Oo=";
    };
    aarch64-darwin = {
      url = "https://github.com/wandb/catnip/releases/download/v${version}/catnip_${version}_darwin_arm64.tar.gz";
      hash = "sha256-6VfZClPkdQlcUwyhfVS5m6pkwxLPboDYic+OYBCSUaQ=";
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
