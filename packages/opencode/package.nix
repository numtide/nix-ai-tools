{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  unzip,
  wrapBuddy,
  fzf,
  ripgrep,
  versionCheckHook,
  versionCheckHomeHook,
  writeShellScriptBin,
}:

let
  pname = "opencode";
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version hashes;

  # Map nix system to release asset name
  platformMap = {
    x86_64-linux = {
      asset = "opencode-linux-x64.tar.gz";
      isZip = false;
    };
    aarch64-linux = {
      asset = "opencode-linux-arm64.tar.gz";
      isZip = false;
    };
    x86_64-darwin = {
      asset = "opencode-darwin-x64.zip";
      isZip = true;
    };
    aarch64-darwin = {
      asset = "opencode-darwin-arm64.zip";
      isZip = true;
    };
  };

  platform = stdenv.hostPlatform.system;
  platformInfo = platformMap.${platform} or (throw "Unsupported system: ${platform}");

  src = fetchurl {
    url = "https://github.com/anomalyco/opencode/releases/download/v${version}/${platformInfo.asset}";
    hash = hashes.${platform};
  };
in
stdenv.mkDerivation {
  inherit pname version src;

  nativeBuildInputs = [
    makeWrapper
  ]
  ++ lib.optionals platformInfo.isZip [
    unzip
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [
    wrapBuddy
  ];

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [
    # clipboardy → system-architecture calls `sysctl -inq sysctl.proc_translated`
    # at import time to detect Rosetta 2. In the Nix sandbox /usr/sbin/sysctl
    # is absent, causing ENOENT and crashing the version check. Provide a
    # minimal stub that reports "not translated" (exit 0, empty output) so the
    # module resolves the native architecture without pulling in system_cmds.
    (writeShellScriptBin "sysctl" "echo 0")
  ];
  # versionCheckHook runs with --ignore-environment by default, stripping PATH.
  # We need PATH preserved so the sysctl stub (and node itself) can be found
  # by child processes spawned during `opencode --version`.
  versionCheckKeepEnvironment = "PATH";

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    stdenv.cc.cc.lib
  ];

  dontConfigure = true;
  dontBuild = true;
  # otherwise strip will remove the compressed typescript code
  dontStrip = true;

  unpackPhase = ''
    runHook preUnpack
  ''
  + lib.optionalString platformInfo.isZip ''
    unzip $src
  ''
  + lib.optionalString (!platformInfo.isZip) ''
    tar -xzf $src
  ''
  + ''
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    install -m755 opencode $out/bin/opencode

    # Wrap to add fzf and ripgrep to PATH
    wrapProgram $out/bin/opencode \
      --prefix PATH : ${
        lib.makeBinPath [
          fzf
          ripgrep
        ]
      }

    runHook postInstall
  '';

  passthru.category = "AI Coding Agents";

  meta = {
    description = "AI coding agent built for the terminal";
    longDescription = ''
      OpenCode is a terminal-based agent that can build anything.
      It provides an interactive AI coding experience directly in your terminal.
    '';
    homepage = "https://github.com/anomalyco/opencode";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    mainProgram = "opencode";
  };
}
