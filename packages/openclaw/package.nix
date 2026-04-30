{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchPnpmDeps,
  cmake,
  git,
  makeWrapper,
  nodejs,
  pnpm,
  pnpmConfigHook,
  versionCheckHook,
  versionCheckHomeHook,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "openclaw";
  version = "2026.4.27";

  src = fetchFromGitHub {
    owner = "openclaw";
    repo = "openclaw";
    rev = "v${finalAttrs.version}";
    hash = "sha256-xduZyKgQ2MK14WhYBYtc/4QaqL2JMgvCq/dtjvnyUkc=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    hash = "sha256-YZlu32+zEUiDsXTjVzTOkpSyf4F2hekPF+A+no3MuY4=";
    fetcherVersion = 2;
  };

  nativeBuildInputs = [
    cmake
    git
    makeWrapper
    nodejs
    pnpm
    pnpmConfigHook
  ];

  # Prevent cmake from automatically running in configure phase
  # (it's only needed for npm postinstall scripts)
  dontUseCmakeConfigure = true;

  preBuild = ''
    # rolldown is a transitive dependency (via tsdown), not a direct root
    # dependency, so pnpm does not link its binary into node_modules/.bin.
    # scripts/bundle-a2ui.mjs probes two hard-coded paths under
    # node_modules/.pnpm/ (the layout produced by pnpm's default isolated
    # node-linker) and falls back to 'pnpm dlx rolldown' (network) when neither
    # exists. Upstream however sets `node-linker=hoisted` in .npmrc, so the
    # package ends up at node_modules/rolldown instead and the probes miss it.
    # Link it where the script expects so the pre-fetched binary is used.
    if [ ! -e node_modules/rolldown/bin/cli.mjs ]; then
      echo "error: rolldown cli.mjs not found in node_modules" >&2
      exit 1
    fi
    mkdir -p node_modules/.pnpm/node_modules
    ln -sfT ../../rolldown node_modules/.pnpm/node_modules/rolldown

    # The runtime-postbuild script calls stageBundledPluginRuntimeDeps which
    # runs "npm install" for bundled plugin runtime dependencies, requiring
    # network access.  Patch it out for the sandbox build — plugin runtime
    # deps are not needed for the main openclaw CLI.
    substituteInPlace scripts/runtime-postbuild.mjs \
      --replace-fail 'stageBundledPluginRuntimeDeps(params);' '/* stageBundledPluginRuntimeDeps(params); — disabled in Nix build */'
  '';

  buildPhase = ''
    runHook preBuild

    pnpm build

    # Build the UI
    pnpm ui:build

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/{bin,lib/openclaw}

    cp -r * $out/lib/openclaw/

    # Remove development/build files not needed at runtime
    pushd $out/lib/openclaw
    rm -rf \
      src \
      test \
      apps \
      Swabble \
      Peekaboo \
      tsconfig.json \
      vitest.config.ts \
      vitest.e2e.config.ts \
      vitest.live.config.ts \
      Dockerfile \
      Dockerfile.sandbox \
      Dockerfile.sandbox-browser \
      docker-compose.yml \
      docker-setup.sh \
      README-header.png \
      CHANGELOG.md \
      CONTRIBUTING.md \
      SECURITY.md \
      appcast.xml \
      pnpm-lock.yaml \
      pnpm-workspace.yaml \
      assets/dmg-background.png \
      assets/dmg-background-small.png

    # Remove test files scattered throughout
    find . -name "__screenshots__" -type d -exec rm -rf {} + 2>/dev/null || true
    find . -name "*.test.ts" -delete
    popd

    makeWrapper ${nodejs}/bin/node $out/bin/openclaw \
      --add-flags "$out/lib/openclaw/dist/entry.js"

    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];
  # Upstream tags may carry a "-N" rebuild suffix (e.g. v2026.4.27) while
  # `openclaw --version` only reports the base version. Strip the suffix
  # before versionCheckHook compares it against the command output.
  preVersionCheck = ''
    version=${lib.head (lib.splitString "-" finalAttrs.version)}
  '';

  passthru.category = "AI Assistants";

  meta = {
    description = "Your own personal AI assistant. Any OS. Any Platform. The lobster way";
    homepage = "https://openclaw.ai";
    changelog = "https://github.com/openclaw/openclaw/releases";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    platforms = lib.platforms.all;
    mainProgram = "openclaw";
  };
})
