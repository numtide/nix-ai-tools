{
  lib,
  stdenvNoCC,
  bun,
  fetchFromGitHub,
  fzf,
  makeBinaryWrapper,
  models-dev,
  ripgrep,
  testers,
  writableTmpDirAsHomeHook,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "opencode";
  version = "1.0.68";
  src = fetchFromGitHub {
    owner = "sst";
    repo = "opencode";
    tag = "v${finalAttrs.version}";
    hash = "sha256-lG6OIi1yT9mqdzmMguUQ5xdIuuEoByVL2GPOVyIny0c=";
  };

  node_modules = stdenvNoCC.mkDerivation {
    pname = "opencode-node_modules";
    inherit (finalAttrs) version src;

    impureEnvVars = lib.fetchers.proxyImpureEnvVars ++ [
      "GIT_PROXY_COMMAND"
      "SOCKS_SERVER"
    ];

    nativeBuildInputs = [
      bun
      writableTmpDirAsHomeHook
    ];

    dontConfigure = true;

    buildPhase = ''
      runHook preBuild

      export BUN_INSTALL_CACHE_DIR=$(mktemp -d)

      bun install \
        --cpu="*" \
        --filter=./packages/opencode \
        --force \
        --frozen-lockfile \
        --ignore-scripts \
        --no-progress \
        --os="*" \
        --production

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out
      while IFS= read -r dir; do
        rel="''${dir#./}"
        dest="$out/$rel"
        mkdir -p "$(dirname "$dest")"
        cp -R "$dir" "$dest"
      done < <(find . -type d -name node_modules -prune | sort)

      runHook postInstall
    '';

    # NOTE: Required else we get errors that our fixed-output derivation references store paths
    dontFixup = true;

    outputHash = "sha256-C1gu8PyV7Byu84i7wM7oSwYQCyG2JG/Qe7g1Csarr0M=";
    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
  };

  nativeBuildInputs = [
    bun
    makeBinaryWrapper
    models-dev
  ];

  patches = [
    # NOTE: Get `_api.json` from the packaged `models-dev` package instead of https://models.dev/.
    ./local-models-dev.patch
    # NOTE: Relax Bun version check to be a warning instead of an error
    ./relax-bun-version-check.patch
  ];

  dontConfigure = true;

  env.MODELS_DEV_API_JSON = "${models-dev}/dist/_api.json";
  env.OPENCODE_VERSION = finalAttrs.version;
  env.OPENCODE_CHANNEL = "stable";

  buildPhase = ''
    runHook preBuild

    # Copy all node_modules including the .bun directory with actual packages
    cp -r ${finalAttrs.node_modules}/node_modules .
    cp -r ${finalAttrs.node_modules}/packages .

    cd packages/opencode

    # Fix symlinks to workspace packages
    chmod -R u+w ./node_modules
    mkdir -p ./node_modules/@opencode-ai
    rm -f ./node_modules/@opencode-ai/{script,sdk,plugin}
    ln -s $(pwd)/../../packages/script ./node_modules/@opencode-ai/script
    ln -s $(pwd)/../../packages/sdk/js ./node_modules/@opencode-ai/sdk
    ln -s $(pwd)/../../packages/plugin ./node_modules/@opencode-ai/plugin

    # Bundle the application with version defines
    cp ${./bundle.ts} ./bundle.ts
    chmod +x ./bundle.ts
    bun run ./bundle.ts

    # Fix WASM paths in worker.ts - use absolute paths to the installed location
    substituteInPlace ./dist/worker.ts \
      --replace-fail 'module2.exports = "../../../tree-sitter-' 'module2.exports = "'"$out"'/lib/opencode/dist/tree-sitter-'

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/opencode
    # Copy the bundled dist directory
    cp -r dist $out/lib/opencode/

    # Copy only the native modules we need (marked as external in bundle.ts)
    mkdir -p $out/lib/opencode/node_modules/.bun
    mkdir -p $out/lib/opencode/node_modules/@opentui

    # Copy @opentui/core platform-specific packages
    for pkg in ../../node_modules/.bun/@opentui+core-*; do
      if [ -d "$pkg" ]; then
        cp -r "$pkg" $out/lib/opencode/node_modules/.bun/$(basename "$pkg")
      fi
    done


    mkdir -p $out/bin
    makeWrapper ${bun}/bin/bun $out/bin/opencode \
      --add-flags "run" \
      --add-flags "$out/lib/opencode/dist/index.js" \
      --prefix PATH : ${
        lib.makeBinPath [
          fzf
          ripgrep
        ]
      } \
      --argv0 opencode

    runHook postInstall
  '';

  postInstall = ''
    # Add symlinks for platform-specific native modules
    for pkg in $out/lib/opencode/node_modules/.bun/@opentui+core-*; do
      if [ -d "$pkg" ]; then
        pkgName=$(basename "$pkg" | sed 's/@opentui+\(core-[^@]*\)@.*/\1/')
        ln -sf ../.bun/$(basename "$pkg")/node_modules/@opentui/$pkgName \
               $out/lib/opencode/node_modules/@opentui/$pkgName
      fi
    done

  '';

  passthru = {
    tests.version = testers.testVersion {
      package = finalAttrs.finalPackage;
      command = "HOME=$(mktemp -d) opencode --version";
      inherit (finalAttrs) version;
    };
    updateScript = ./update.sh;
  };

  meta = {
    description = "AI coding agent built for the terminal";
    longDescription = ''
      OpenCode is a terminal-based agent that can build anything.
      It combines a TypeScript/JavaScript core with a Go-based TUI
      to provide an interactive AI coding experience.
    '';
    homepage = "https://github.com/sst/opencode";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
    mainProgram = "opencode";
  };
})
