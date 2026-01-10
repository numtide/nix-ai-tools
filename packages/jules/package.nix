{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  wrapBuddy,
  versionCheckHook,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version hashes;

  platformMap = {
    x86_64-linux = "linux_amd64";
    aarch64-linux = "linux_arm64";
    x86_64-darwin = "darwin_amd64";
    aarch64-darwin = "darwin_arm64";
  };

  platform = stdenv.hostPlatform.system;
  platformSuffix = platformMap.${platform} or (throw "Unsupported system: ${platform}");
in
stdenv.mkDerivation {
  pname = "jules";
  inherit version;

  src = fetchurl {
    url = "https://storage.googleapis.com/jules-cli/v${version}/jules_external_v${version}_${platformSuffix}.tar.gz";
    hash = hashes.${platform};
  };

  nativeBuildInputs = [ makeWrapper ] ++ lib.optionals stdenv.hostPlatform.isLinux [ wrapBuddy ];

  # The tarball extracts to a directory with jules binary and licenses/ subdirectory
  # Explicitly set sourceRoot to prevent Nix from picking licenses/ as the source
  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    install -Dm755 jules $out/bin/jules

    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];
  # Jules uses "version" subcommand, not --version flag
  versionCheckProgramArg = [ "version" ];

  passthru.category = "AI Coding Agents";

  meta = with lib; {
    description = "Jules, the asynchronous coding agent from Google, in the terminal";
    homepage = "https://jules.google";
    license = licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "jules";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
  };
}
