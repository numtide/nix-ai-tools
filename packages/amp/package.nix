{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  wrapBuddy,
  ripgrep,
  cctools,
  darwin,
  rcodesign,
  versionCheckHook,
  versionCheckHomeHook,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version;
  hashes = versionData.binaryHashes;

  platformMap = {
    x86_64-linux = "linux-x64";
    aarch64-linux = "linux-arm64";
    x86_64-darwin = "darwin-x64";
    aarch64-darwin = "darwin-arm64";
  };

  platform = stdenv.hostPlatform.system;
  platformSuffix = platformMap.${platform} or (throw "Unsupported system: ${platform}");
in
stdenv.mkDerivation {
  pname = "amp";
  inherit version;

  src = fetchurl {
    url = "https://storage.googleapis.com/amp-public-assets-prod-0/cli/${version}/amp-${platformSuffix}";
    hash = hashes.${platform};
  };

  dontUnpack = true;

  nativeBuildInputs = [
    makeWrapper
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [ wrapBuddy ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [
    cctools
    rcodesign
  ];

  dontStrip = true; # do not mess with the bun runtime

  installPhase = ''
    runHook preInstall

    install -Dm755 $src $out/bin/amp

    runHook postInstall
  '';

  # Rewrite the Bun ICU dependency to use Nix-provided darwin.ICU instead of
  # /usr/lib/libicucore.A.dylib, which needs /usr/share/icu/ at runtime.
  # This avoids __noChroot and lets the build run in the sandbox on macOS.
  # Re-signing is required because modifying the binary invalidates its signature.
  #
  # Uses a single wrapProgram call to avoid double-wrapping which causes the
  # process to show as ".amp-wrapped_" instead of "amp" in ps/htop.
  # --argv0 ensures the process name is preserved through the wrapper.
  postFixup = ''
    ${lib.optionalString stdenv.hostPlatform.isDarwin ''
      ${lib.getExe' cctools "${cctools.targetPrefix}install_name_tool"} $out/bin/amp \
        -change /usr/lib/libicucore.A.dylib '${lib.getLib darwin.ICU}/lib/libicucore.A.dylib'
      ${lib.getExe rcodesign} sign --code-signature-flags linker-signed $out/bin/amp
    ''}
    wrapProgram $out/bin/amp \
      --argv0 amp \
      --prefix PATH : ${lib.makeBinPath [ ripgrep ]} \
      --set AMP_SKIP_UPDATE_CHECK 1
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];

  passthru.category = "AI Coding Agents";

  meta = with lib; {
    description = "CLI for Amp, an agentic coding tool in research preview from Sourcegraph";
    homepage = "https://ampcode.com/";
    license = licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    maintainers = with maintainers; [ ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    mainProgram = "amp";
  };
}
