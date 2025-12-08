{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchYarnDeps,
  yarnConfigHook,
  yarnInstallHook,
  nodejs,
  makeWrapper,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "happy-server";
  version = "0-unstable-2025-11-28";

  src = fetchFromGitHub {
    owner = "slopus";
    repo = "happy-server";
    rev = "84ed0273024469b204e59d97002069765f20086d";
    hash = "sha256-fH9SeYGwvnOKeD6F9nk316YnP83dX+CtYUtqlCYj5LM=";
  };

  yarnOfflineCache = fetchYarnDeps {
    yarnLock = finalAttrs.src + "/yarn.lock";
    hash = "sha256-zTdeLQowJWLJE5SHubnHUnRGHvmdhCNq+6jJ77UdCCo=";
  };

  nativeBuildInputs = [
    nodejs
    yarnConfigHook
    yarnInstallHook
    makeWrapper
  ];

  # Skip build phase since the app runs with tsx (no compilation needed)
  dontBuild = true;

  # Create wrapper script that will run tsx with the main.ts entry point
  postInstall = ''
    # Create the server wrapper
    mkdir -p $out/bin
    cat > $out/bin/happy-server <<EOF
#!/usr/bin/env bash
set -e
# Change to the package directory so tsconfig.json paths work
cd $out/lib/node_modules/happy-server
# Set NODE_PATH to help with module resolution
export NODE_PATH="\$NODE_PATH:$out/lib/node_modules/happy-server/node_modules"
# Users will need to run 'prisma generate' and set up the database before running
exec ${lib.getExe nodejs} --import ./node_modules/tsx/dist/esm/index.mjs ./sources/main.ts "\$@"
EOF
    chmod +x $out/bin/happy-server
  '';

  meta = {
    description = "Happy Coder backend - Minimal backend for open-source end-to-end encrypted Claude Code clients";
    homepage = "https://github.com/slopus/happy-server";
    changelog = "https://github.com/slopus/happy-server/commits/main";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with lib.maintainers; [ ];
    mainProgram = "happy-server";
    platforms = lib.platforms.all;
  };
})
