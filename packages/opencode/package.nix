{
  lib,
  stdenvNoCC,
  bun,
  fetchFromGitHub,
  fetchurl,
  fzf,
  makeBinaryWrapper,
  models-dev,
  nix-update-script,
  ripgrep,
  testers,
  writableTmpDirAsHomeHook,
}:

let
  # Use baseline Bun on Linux to avoid AVX512 crash issues
  bunToUse = if stdenvNoCC.hostPlatform.isLinux then
    bun.overrideAttrs (old: {
      src = fetchurl {
        url = "https://github.com/oven-sh/bun/releases/download/bun-v${bun.version}/bun-linux-x64-baseline.zip";
        hash = "sha256-f/CaSlGeggbWDXt2MHLL82Qvg3BpAWVYbTA/ryFpIXI=";
      };
    })
  else bun;
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "opencode";
  version = "1.0.61";
  src = fetchFromGitHub {
    owner = "sst";
    repo = "opencode";
    tag = "v${finalAttrs.version}";
    hash = "sha256-crgBsWRpdQ2S1qJtlkKs1Nk1SP830w7dJGzK9lbjprU=";
  };

  node_modules = stdenvNoCC.mkDerivation {
    pname = "opencode-node_modules";
    inherit (finalAttrs) version src;

    impureEnvVars = lib.fetchers.proxyImpureEnvVars ++ [
      "GIT_PROXY_COMMAND"
      "SOCKS_SERVER"
    ];

    nativeBuildInputs = [
      bunToUse
      writableTmpDirAsHomeHook
    ];

    dontConfigure = true;

    buildPhase = ''
      runHook preBuild

      export BUN_INSTALL_CACHE_DIR=$(mktemp -d)

      # NOTE: Without `--linker=hoisted` the necessary platform specific packages are not created, i.e. `@parcel/watcher-<os>-<arch>` and `@opentui/core-<os>-<arch>`
      bun install \
        --filter=./packages/opencode \
        --force \
        --frozen-lockfile \
        --ignore-scripts \
        --linker=hoisted \
        --no-progress \
        --production

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out/node_modules
      cp -R ./node_modules $out

      runHook postInstall
    '';

    # NOTE: Required else we get errors that our fixed-output derivation references store paths
    dontFixup = true;

    outputHash = (lib.importJSON ./hashes.json).node_modules.${stdenvNoCC.hostPlatform.system};
    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
  };

  nativeBuildInputs = [
    bunToUse
    makeBinaryWrapper
    models-dev
  ];

  patches = [
    # NOTE: Patch `packages/opencode/src/provider/models-macro.ts` to get contents of
    # `_api.json` from the file bundled with `bun build`.
    ./local-models-dev.patch
    # Relax Bun version check to be a warning instead of an error
    ./relax-bun-version-check.patch
  ];

  postPatch = ''
    # don't require a specifc bun version
    substituteInPlace packages/script/src/index.ts \
      --replace-fail "if (process.versions.bun !== expectedBunVersion)" "if (false)"
  '';

  dontConfigure = true;

  env.MODELS_DEV_API_JSON = "${models-dev}/dist/_api.json";
  env.OPENCODE_VERSION = finalAttrs.version;
  env.OPENCODE_CHANNEL = "stable";

  buildPhase = ''
    runHook preBuild

    cd packages/opencode
    cp -r ${finalAttrs.node_modules}/node_modules .

    # Fix symlinks to workspace packages
    chmod -R u+w ./node_modules
    rm -f ./node_modules/@opencode-ai/{script,sdk,plugin}
    ln -s $(pwd)/../../packages/script ./node_modules/@opencode-ai/script
    ln -s $(pwd)/../../packages/sdk/js ./node_modules/@opencode-ai/sdk
    ln -s $(pwd)/../../packages/plugin ./node_modules/@opencode-ai/plugin

    # Bundle the application with version defines
    cp ${./bundle.ts} ./bundle.ts
    chmod +x ./bundle.ts
    bun run ./bundle.ts

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/opencode
    # Copy the bundled dist directory
    cp -r dist $out/lib/opencode/
    # Also copy node_modules for native modules like @opentui/core-<platform>
    cp -r node_modules $out/lib/opencode/

    mkdir -p $out/bin
    makeWrapper ${bunToUse}/bin/bun $out/bin/opencode \
      --add-flags "run" \
      --add-flags "$out/lib/opencode/dist/index.js" \
      --prefix PATH : ${lib.makeBinPath [ fzf ripgrep ]} \
      --argv0 opencode

    runHook postInstall
  '';

  postInstall = ''
    # Remove workspace symlinks that point to build directory
    rm -f $out/lib/opencode/node_modules/@opencode-ai/{script,sdk,plugin}
    rm -f $out/lib/opencode/node_modules/opencode
    rm -f $out/lib/opencode/node_modules/.bin/opencode 2>/dev/null || true
  '';


  passthru = {
    tests.version = testers.testVersion {
      package = finalAttrs.finalPackage;
      command = "HOME=$(mktemp -d) opencode --version";
      inherit (finalAttrs) version;
    };
    updateScript = nix-update-script {
      extraArgs = [
        "--subpackage"
        "node_modules"
      ];
    };
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
