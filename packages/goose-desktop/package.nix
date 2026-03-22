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
  # Create a source with package-lock.json included at the root level
  # fetchNpmDepsWithPackuments looks for the lock file at the source root
  # and npmConfigHook expects it in the npmRoot directory (ui/desktop)
  srcWithLock = runCommand "goose-desktop-src-with-lock" { } ''
    mkdir -p $out
    cp -r ${
      fetchFromGitHub {
        owner = "block";
        repo = "goose";
        rev = "v1.28.0";
        hash = "sha256-/1TtsnNiLoTkvyeFR282qSpo+Jt3pvFxduJ7lyzsTXI=";
      }
    }/* $out/
    # Copy lock file to root for fetchNpmDepsWithPackuments
    cp ${./package-lock.json} $out/package-lock.json
    # Make ui/desktop writable and copy lock file there for npmConfigHook
    chmod +w $out/ui/desktop
    cp ${./package-lock.json} $out/ui/desktop/package-lock.json
  '';
in
buildNpmPackage rec {
  inherit npmConfigHook;
  pname = "goose-desktop";
  version = "1.28.0";

  src = srcWithLock;

  npmDeps = fetchNpmDepsWithPackuments {
    inherit src;
    name = "${pname}-${version}-npm-deps";
    hash = "sha256-mp3SC1SYJt5bupqqQmKT05nuR2ZpQz3Jn0lLvkUj9yk=";
    fetcherVersion = 2;
  };
  makeCacheWritable = true;

  # The npm package is in the ui/desktop subdirectory
  npmRoot = "ui/desktop";

  # Use legacy peer deps to match how the lock file was generated
  npmFlags = [ "--legacy-peer-deps" ];

  nativeBuildInputs = [ makeWrapper ];

  env.ELECTRON_SKIP_BINARY_DOWNLOAD = "1";

  # Use pre-built goosed from goose-server package
  preBuild = ''
    # Copy goosed binary to expected location for Electron bundling
    mkdir -p ui/desktop/src/bin
    cp ${goose-server}/bin/goosed ui/desktop/src/bin/
  '';

  buildPhase = ''
    runHook preBuild

    # Ensure our electron major version matches what upstream expects
    upstream_electron=$(node -p "require('./ui/desktop/package.json').devDependencies.electron")
    upstream_major=''${upstream_electron%%.*}
    nix_major=${lib.versions.major electron_41.version}
    if [[ "$upstream_major" != "$nix_major" ]]; then
      echo "error: upstream expects electron $upstream_electron (major $upstream_major), but we provide electron ${electron_41.version} (major $nix_major)"
      echo "Update the electron_41 input in package.nix to match."
      exit 1
    fi

    # Build the Electron app
    cd ui/desktop
    npx electron-forge package
    cd ../..

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/goose-desktop

    # Copy electron-forge build output
    if [ -d "ui/desktop/out/*.app" ]; then
      cp -r ui/desktop/out/*.app $out/share/goose-desktop/
    fi
    if [ -d "ui/desktop/out/goose-"* ]; then
      cp -r ui/desktop/out/goose-* $out/share/goose-desktop/
    fi
    if [ -d "ui/desktop/out/Goose-"* ]; then
      cp -r ui/desktop/out/Goose-* $out/share/goose-desktop/
    fi

    mkdir -p $out/bin

    # Determine the app directory name
    app_dir=$(ls $out/share/goose-desktop | head -1)

    # Create wrapper script
    if [[ "$app_dir" == *.app ]]; then
      # macOS app bundle
      makeWrapper $out/share/goose-desktop/$app_dir/Contents/MacOS/Goose $out/bin/goose-desktop
    else
      # Linux/Windows
      makeWrapper ${electron_41}/bin/electron $out/bin/goose-desktop \
        --add-flags "$out/share/goose-desktop/$app_dir" \
        --set ELECTRON_FORCE_IS_PACKAGED 1
    fi

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
