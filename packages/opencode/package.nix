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
  version = "1.0.62";
  src = fetchFromGitHub {
    owner = "sst";
    repo = "opencode";
    tag = "v${finalAttrs.version}";
    hash = "sha256-E3bND81OlgnzO2f0ZYk//d0gDa1mrJ4ai8//cRRJ6Hg=";
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
    # NOTE: Removes unnecessary build targets in `packages/opencode/script/build.ts`
    ./remove-unnecessary-build-targets.patch
    # NOTE: Skip platform-specific build install commands in
    # `packages/opencode/script/build.ts` since packages are already in node_modules
    ./skip-bun-install.patch
  ];

  configurePhase = ''
    runHook preConfigure

    cp -R ${finalAttrs.node_modules}/. .

    runHook postConfigure
  '';

  env.MODELS_DEV_API_JSON = "${models-dev}/dist/_api.json";
  env.OPENCODE_VERSION = finalAttrs.version;
  env.OPENCODE_CHANNEL = "stable";

  preBuild = ''
    chmod -R u+w ./packages/opencode/node_modules
    pushd ./packages/opencode/node_modules/@parcel/
      for pkg in ../../../../node_modules/.bun/@parcel+watcher-*; do
        linkName=$(basename "$pkg" | sed 's/@.*+\(.*\)@.*/\1/')
        ln -sf "$pkg/node_modules/@parcel/$linkName" "$linkName"
      done
    popd

    pushd ./packages/opencode/node_modules/@opentui/
      for pkg in ../../../../node_modules/.bun/@opentui+core-*; do
        linkName=$(basename "$pkg" | sed 's/@.*+\(.*\)@.*/\1/')
        ln -sf "$pkg/node_modules/@opentui/$linkName" "$linkName"
      done
    popd
  '';

  buildPhase = ''
    runHook preBuild

    cd ./packages/opencode
    bun run ./script/build.ts --single

    runHook postBuild
  '';

  dontStrip = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 dist/opencode-*/bin/opencode $out/bin/opencode

    runHook postInstall
  '';

  postInstall = ''
    wrapProgram $out/bin/opencode \
      --prefix PATH : ${
        lib.makeBinPath [
          fzf
          ripgrep
        ]
      }
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
