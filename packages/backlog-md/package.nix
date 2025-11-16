{
  lib,
  stdenv,
  stdenvNoCC,
  fetchFromGitHub,
  bun,
  makeBinaryWrapper,
  nodejs,
  autoPatchelfHook,
}:

let
  fetchBunDeps =
    { src, hash, ... }@args:
    stdenvNoCC.mkDerivation {
      pname = args.pname or "${src.name or "source"}-bun-deps";
      version = args.version or src.version or "unknown";
      inherit src;

      impureEnvVars = lib.fetchers.proxyImpureEnvVars ++ [
        "GIT_PROXY_COMMAND"
        "SOCKS_SERVER"
      ];

      nativeBuildInputs = [ bun ];

      dontConfigure = true;

      buildPhase = ''
        runHook preBuild
        export HOME=$TMPDIR
        # Disable npm lifecycle scripts to prevent husky from running
        export npm_config_ignore_scripts=true
        bun install --no-progress --frozen-lockfile --ignore-scripts
        runHook postBuild
      '';

      installPhase = ''
        runHook preInstall
        mkdir -p $out
        cp -R ./node_modules $out
        # Store bun.lock to verify version consistency
        cp ./bun.lock $out/
        runHook postInstall
      '';

      dontFixup = true;

      outputHash = hash;
      outputHashAlgo = "sha256";
      outputHashMode = "recursive";
    };

  version = "1.20.1";

  src = fetchFromGitHub {
    owner = "MrLesk";
    repo = "Backlog.md";
    rev = "v${version}";
    hash = "sha256-WpfFhFqqVTHGEfa1jTOU4kY3eFpAVu2G1O8lFBIScVA=";
  };

  # Create a fixed-output derivation for dependencies
  node_modules = fetchBunDeps {
    pname = "backlog-md-bun-deps";
    inherit version src;
    hash = "sha256-mzah9FUHq7JrnPGts8M8VkCAGTwXpU2LeppKBmx5Wg8=";
  };
in
stdenv.mkDerivation rec {
  pname = "backlog-md";
  inherit version src;

  nativeBuildInputs = [
    bun
    nodejs
    makeBinaryWrapper
    autoPatchelfHook
  ];

  buildInputs = [
    stdenv.cc.cc.lib
  ];

  autoPatchelfIgnoreMissingDeps = [
    "libc.musl-x86_64.so.1"
  ];

  dontConfigure = true;

  buildPhase = ''
    runHook preBuild

    # Verify that the bun.lock files match between source and node_modules
    if ! diff -q ./bun.lock ${node_modules}/bun.lock > /dev/null; then
      echo "ERROR: bun.lock mismatch between source and node_modules!"
      echo "The node_modules derivation needs to be rebuilt for the new version."
      echo "To fix this, update the outputHash in the node_modules derivation."
      exit 1
    fi

    # Copy node_modules locally so we can patch ELF files
    cp -R ${node_modules}/node_modules .
    chmod -R u+w node_modules

    # Patch shebangs in node_modules
    patchShebangs node_modules

    # Patch ELF files in node_modules to fix native dependencies
    echo "Running autoPatchelf on node_modules..."
    autoPatchelf node_modules

    # Build the project to create the binary
    export HOME=$TMPDIR
    export PATH="$PWD/node_modules/.bin:$PATH"

    # Disable npm lifecycle scripts to prevent husky from running
    export npm_config_ignore_scripts=true
    bun run build

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin

    # The build command creates a compiled binary
    cp dist/backlog $out/bin/backlog
    chmod +x $out/bin/backlog

    runHook postInstall
  '';

  # Don't strip the binary - bun compile embeds the JavaScript program
  # in the executable and stripping would remove it
  dontStrip = true;

  passthru = {
    updateScript = ./update.sh;
  };

  meta = with lib; {
    description = "Backlog.md - A tool for managing project collaboration between humans and AI Agents in a git ecosystem";
    homepage = "https://github.com/MrLesk/Backlog.md";
    changelog = "https://github.com/MrLesk/Backlog.md/releases";
    license = licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with maintainers; [ ];
    mainProgram = "backlog";
    platforms = [ "x86_64-linux" ];
  };
}
