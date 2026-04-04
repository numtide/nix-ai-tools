{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  fetchNpmDepsWithPackuments,
  npmConfigHook,
  makeWrapper,
  runCommand,
  electron_41,
  goose-server,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  version = versionData.version;
  src = fetchFromGitHub {
    owner = "block";
    repo = "goose";
    rev = "v${version}";
    hash = versionData.sourceHash;
  };

  srcWithLock = runCommand "goose-desktop-src-with-lock" { } ''
    mkdir -p $out
    cp -r ${src}/* $out/
    cp ${./package-lock.json} $out/package-lock.json
    chmod +w $out/ui/desktop
    cp ${./package-lock.json} $out/ui/desktop/package-lock.json
  '';
in
buildNpmPackage rec {
  inherit npmConfigHook version;
  pname = "goose-desktop";

  src = srcWithLock;

  npmDeps = fetchNpmDepsWithPackuments {
    inherit src;
    name = "${pname}-${version}-npm-deps";
    hash = versionData.npmDepsHash;
    fetcherVersion = 2;
  };
  makeCacheWritable = true;

  npmRoot = "ui/desktop";
  npmFlags = [ "--legacy-peer-deps" ];

  nativeBuildInputs = [ makeWrapper ];

  env.ELECTRON_SKIP_BINARY_DOWNLOAD = "1";
  env.ELECTRON_OVERRIDE_DIST_PATH = "${electron_41}/bin";

  postPatch = ''
    # Nix manages updates for packaged builds.
    substituteInPlace ui/desktop/package.json \
      --replace-fail '"@aaif/goose-acp": "workspace:*"' '"@aaif/goose-acp": "file:../acp"'
    node -e "const fs=require('fs'); const p='ui/desktop/forge.config.ts'; const s=fs.readFileSync(p,'utf8'); fs.writeFileSync(p, s.replace('  asar: true,', '  asar: true,\\n  prune: false,'));"
    substituteInPlace ui/desktop/forge.config.ts \
      --replace-fail "  rebuildConfig: {}," "  rebuildConfig: { types: [] },"
    rm -f ui/package.json ui/pnpm-workspace.yaml
    substituteInPlace ui/desktop/src/updates.ts \
      --replace-fail "export const UPDATES_ENABLED = true;" "export const UPDATES_ENABLED = false;"
  '';

  preBuild = ''
    mkdir -p ui/desktop/src/bin
    cp ${goose-server}/bin/goosed ui/desktop/src/bin/
  '';

  buildPhase = ''
    runHook preBuild

    upstream_electron=$(node -p "require('./ui/desktop/package.json').devDependencies.electron")
    upstream_major=''${upstream_electron%%.*}
    nix_major=${lib.versions.major electron_41.version}
    if [[ "$upstream_major" != "$nix_major" ]]; then
      echo "error: upstream expects electron $upstream_electron (major $upstream_major), but we provide electron ${electron_41.version} (major $nix_major)"
      echo "Update the electron_41 input in package.nix to match."
      exit 1
    fi

    cd ui/desktop
    node scripts/build-main.js
    npx vite build --config vite.preload.config.mts
    npx vite build --config vite.renderer.config.mts --outDir .vite/renderer/main_window
    cd ../..

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    app_root=$out/share/goose-desktop/app
    mkdir -p $app_root

    cp -r ui/desktop/. $app_root/
    cp -r ui/acp $out/share/goose-desktop/acp
    patchShebangs $app_root

    mkdir -p $out/bin
    makeWrapper ${electron_41}/bin/electron $out/bin/goose-desktop \
      --add-flags "$app_root" \
      --set-default ENABLE_DEV_UPDATES false

    runHook postInstall
  '';

  passthru.category = "AI Coding Agents";

  meta = with lib; {
    description = "Desktop app for Goose - a local, extensible, open source AI agent";
    homepage = "https://github.com/block/goose";
    changelog = "https://github.com/block/goose/releases/tag/v${version}";
    license = licenses.asl20;
    sourceProvenance = with sourceTypes; [ fromSource ];
    mainProgram = "goose-desktop";
    platforms = platforms.linux;
  };
}
