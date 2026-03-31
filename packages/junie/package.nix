{
  lib,
  stdenv,
  fetchurl,
  unzip,
  makeWrapper,
  autoPatchelfHook,
  versionCheckHook,
  zlib,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version hashes;

  platforms = {
    x86_64-linux = "linux-amd64";
    aarch64-linux = "linux-aarch64";
    x86_64-darwin = "macos-amd64";
    aarch64-darwin = "macos-aarch64";
  };

  platform =
    platforms.${stdenv.hostPlatform.system}
      or (throw "Unsupported system: ${stdenv.hostPlatform.system}");

  src = fetchurl {
    url = "https://github.com/JetBrains/junie/releases/download/${version}/junie-release-${version}-${platform}.zip";
    hash = hashes.${stdenv.hostPlatform.system};
  };
in
stdenv.mkDerivation {
  pname = "junie";
  inherit version src;

  nativeBuildInputs = [
    unzip
    makeWrapper
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];

  # The bundled JRE contains modules for AWT/sound/etc that we don't need for
  # the CLI; mark their deps optional so autoPatchelfHook doesn't fail.
  autoPatchelfIgnoreMissingDeps = [
    "libasound.so.2"
    "libfreetype.so.6"
    "libharfbuzz.so.0"
    "libgif.so.7"
    "libjpeg.so.8"
    "liblcms2.so.2"
    "libpng16.so.16"
    "libpcsclite.so.1"
    "libX11.so.6"
    "libXext.so.6"
    "libXi.so.6"
    "libXrender.so.1"
    "libXtst.so.6"
  ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    (lib.getLib stdenv.cc.cc) # libstdc++, libgcc_s
    zlib
  ];

  sourceRoot = ".";

  # Don't strip: the bundled JRE's jimage (lib/modules) gets corrupted and
  # macOS binaries are signed.
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/opt $out/bin
    cp -r junie-app $out/opt/junie

    # On Linux the launcher resolves paths relative to its own location, so a
    # plain symlink works. On macOS the jpackage launcher walks the directory
    # tree from argv[0] and gets confused by the symlink layout — use a wrapper
    # that execs the real binary so $0 points into $out/opt.
    ${
      if stdenv.hostPlatform.isDarwin then
        ''
          makeWrapper $out/opt/junie/bin/junie $out/bin/junie
        ''
      else
        ''
          ln -s $out/opt/junie/bin/junie $out/bin/junie
        ''
    }

    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckProgramArg = "--version";
  # OpenJDK resolves user.home via getpwuid() and ignores $HOME. In the Nix
  # sandbox /etc/passwd lists the home directory as the literal string
  # `"/build"` (quotes included), so Junie tries to mkdir a path starting
  # with `/"` and blows up before it can print the version.
  versionCheckKeepEnvironment = [ "JAVA_TOOL_OPTIONS" ];
  preVersionCheck = ''
    export JAVA_TOOL_OPTIONS="-Duser.home=$(mktemp -d)"
  '';

  passthru.category = "AI Coding Agents";

  meta = {
    description = "LLM-agnostic coding agent for the terminal, by JetBrains";
    homepage = "https://junie.jetbrains.com/";
    changelog = "https://github.com/JetBrains/junie/releases/tag/${version}";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    maintainers = with lib.maintainers; [ mic92 ];
    mainProgram = "junie";
    platforms = builtins.attrNames platforms;
  };
}
