{
  lib,
  stdenv,
  stdenvNoCC,
  bun,
  nodejs,
  fetchFromGitHub,
  models-dev,
  nix-update-script,
  testers,
  writableTmpDirAsHomeHook,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "opencode";
  version = "1.0.55";
  src = fetchFromGitHub {
    owner = "sst";
    repo = "opencode";
    tag = "v${finalAttrs.version}";
    hash = "sha256-iKD58BA1ueIVsQXvsAZwXCMkSAM1ZzYPL8WGtKANfIE=";
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

      # NOTE: Disabling post-install scripts with `--ignore-scripts` to avoid
      # shebang issues
      # NOTE: `--linker=hoisted` temporarily disables Bun's isolated installs,
      # which became the default in Bun 1.3.0.
      # This workaround is required because the 'yargs' dependency is currently
      # missing when building opencode. Remove this flag once upstream is
      # compatible with Bun 1.3.0.
      bun install \
        --force \
        --ignore-scripts \
        --filter=opencode \
        --frozen-lockfile \
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

    # Required else we get errors that our fixed-output derivation references store paths
    dontFixup = true;

    outputHash = (lib.importJSON ./hashes.json).node_modules.${stdenv.hostPlatform.system};
    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
  };

  nativeBuildInputs = [
    bun
    nodejs
    models-dev
  ];

  patchFlags = [ "-p1" ];

  patches = [
    # Patch `packages/opencode/src/provider/models-macro.ts` to get contents of
    # `_api.json` from the file bundled with `bun build`.
    ./local-models-dev.patch
    # Skip npm pack commands in build.ts since packages are already in node_modules
    ./skip-npm-pack.patch
  ];

  configurePhase = ''
    runHook preConfigure

    cd packages/opencode
    cp -R ${finalAttrs.node_modules}/node_modules .
    chmod -R u+w ./node_modules
    # make symlinks absolute to avoid issues with bun build
    rm ./node_modules/@opencode-ai/script
    ln -s $(pwd)/../../packages/script ./node_modules/@opencode-ai/script
    rm -f ./node_modules/@opencode-ai/sdk
    ln -s $(pwd)/../../packages/sdk/js ./node_modules/@opencode-ai/sdk
    rm -f ./node_modules/@opencode-ai/plugin
    ln -s $(pwd)/../../packages/plugin ./node_modules/@opencode-ai/plugin

    runHook postConfigure
  '';

  env.MODELS_DEV_API_JSON = "${models-dev}/dist/_api.json";
  env.OPENCODE_VERSION = finalAttrs.version;
  env.OPENCODE_CHANNEL = "stable";

  buildPhase = ''
    runHook preBuild

    # Run the build script which will create the compiled binary
    bun run ./script/build.ts --single

    runHook postBuild
  '';

  dontStrip = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 dist/opencode-*/bin/opencode $out/bin/opencode

    runHook postInstall
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
