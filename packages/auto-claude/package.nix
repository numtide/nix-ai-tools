{
  lib,
  flake,
  buildNpmPackage,
  fetchFromGitHub,
  fetchNpmDepsWithPackuments,
  npmConfigHook,
  makeWrapper,
  electron_39,
  python3,
}:

buildNpmPackage rec {
  pname = "auto-claude";
  version = "2.7.6";

  src = fetchFromGitHub {
    owner = "AndyMik90";
    repo = "Auto-Claude";
    rev = "v${version}";
    hash = "sha256-MwT/FGpnAbGjJAGoKJkyL0ngKWtPIpQiCSN2LzHSMAY=";
  };

  npmDeps = fetchNpmDepsWithPackuments {
    inherit src;
    name = "${pname}-${version}-npm-deps";
    hash = "sha256-iuN5f2TRD+C1CB/r3DdQEOQMio5x6G0ibNo83mktxrk=";
    fetcherVersion = 2;
  };
  inherit npmConfigHook;
  makeCacheWritable = true;

  nativeBuildInputs = [ makeWrapper ];

  env.ELECTRON_SKIP_BINARY_DOWNLOAD = "1";

  patches = [ ./nix.patch ];

  npmFlags = [ "--ignore-scripts" ];

  buildPhase = ''
    runHook preBuild

    # Ensure our electron major version matches what upstream expects.
    # This will fail loudly on version bumps instead of silently diverging.
    upstream_electron=$(node -p "require('./apps/frontend/package.json').devDependencies.electron")
    upstream_major=''${upstream_electron%%.*}
    nix_major=${lib.versions.major electron_39.version}
    if [[ "$upstream_major" != "$nix_major" ]]; then
      echo "error: upstream expects electron $upstream_electron (major $upstream_major), but we provide electron ${electron_39.version} (major $nix_major)"
      echo "Update the electron_39 input in package.nix to match."
      exit 1
    fi

    cd apps/frontend
    npx electron-vite build
    cd ../..

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/auto-claude

    # Copy electron-vite build output
    cp -r apps/frontend/out $out/share/auto-claude/
    cp apps/frontend/package.json $out/share/auto-claude/

    # Copy runtime node_modules from the workspace root (npm hoists deps there).
    # This includes @lydell/node-pty and its platform-specific prebuilt binaries,
    # which are needed at runtime since electron-vite externalizes them.
    npm prune --omit=dev
    # Remove workspace symlinks that point to build-time paths
    find node_modules -maxdepth 1 -type l -delete
    cp -r node_modules $out/share/auto-claude/

    # Include the Python backend as a resource
    mkdir -p $out/share/auto-claude/resources/backend
    cp -r apps/backend/* $out/share/auto-claude/resources/backend/

    mkdir -p $out/bin
    # The app's PythonEnvManager searches for python3 on PATH to create a
    # venv and pip-install backend dependencies at first launch.
    # ELECTRON_FORCE_IS_PACKAGED makes app.isPackaged return true so the
    # app uses production code paths (no DevTools, venv in userData, etc.).
    makeWrapper ${electron_39}/bin/electron $out/bin/auto-claude \
      --add-flags "$out/share/auto-claude" \
      --set ELECTRON_FORCE_IS_PACKAGED 1 \
      --prefix PATH : ${lib.makeBinPath [ python3 ]}

    runHook postInstall
  '';

  doInstallCheck = false;

  passthru.category = "Claude Code Ecosystem";

  meta = {
    description = "Autonomous multi-agent coding framework powered by Claude AI";
    homepage = "https://github.com/AndyMik90/Auto-Claude";
    changelog = "https://github.com/AndyMik90/Auto-Claude/releases/tag/v${version}";
    license = lib.licenses.agpl3Only;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ xorilog ];
    mainProgram = "auto-claude";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
  };
}
