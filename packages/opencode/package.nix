{
  lib,
  stdenvNoCC,
  bun,
  fetchFromGitHub,
  fzf,
  makeBinaryWrapper,
  models-dev,
  ripgrep,
  writableTmpDirAsHomeHook,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version hash outputHash;
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "opencode";
  inherit version;

  src = fetchFromGitHub {
    owner = "sst";
    repo = "opencode";
    tag = "v${version}";
    inherit hash;
  };

  # NOTE: We use upstream's normalization scripts for reproducible node_modules,
  # but cannot use their bun-build.ts compilation approach due to
  # https://github.com/sst/opencode/issues/4575 (bun compile fails in Nix sandbox).
  # Instead, we bundle the JavaScript and run it with the bun runtime.
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
        --os="*" \
        --filter=./packages/opencode \
        --frozen-lockfile \
        --ignore-scripts \
        --linker=isolated \
        --no-progress \
        --production

      # Use upstream scripts for reproducible node_modules
      bun --bun ./nix/scripts/canonicalize-node-modules.ts
      bun --bun ./nix/scripts/normalize-bun-binaries.ts

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

    inherit outputHash;
    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
  };

  nativeBuildInputs = [
    bun
    makeBinaryWrapper
    models-dev
  ];

  patches = [
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

    (
      cd packages/opencode

      # Fix symlinks to workspace packages
      chmod -R u+w ./node_modules
      mkdir -p ./node_modules/@opencode-ai
      rm -f ./node_modules/@opencode-ai/{script,sdk,plugin}
      ln -s $(pwd)/../../packages/script ./node_modules/@opencode-ai/script
      ln -s $(pwd)/../../packages/sdk/js ./node_modules/@opencode-ai/sdk
      ln -s $(pwd)/../../packages/plugin ./node_modules/@opencode-ai/plugin

      # Use upstream bundle.ts for Nix-compatible bundling
      cp ../../nix/bundle.ts ./bundle.ts
      chmod +x ./bundle.ts
      bun run ./bundle.ts
    )

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    cd packages/opencode
    if [ ! -d dist ]; then
      echo "ERROR: dist directory missing after bundle step"
      exit 1
    fi

    mkdir -p $out/lib/opencode
    cp -r dist $out/lib/opencode/
    chmod -R u+w $out/lib/opencode/dist

    # Select bundled worker assets deterministically (sorted find output)
    worker_file=$(find "$out/lib/opencode/dist" -type f \( -path '*/tui/worker.*' -o -name 'worker.*' \) | sort | head -n1)
    parser_worker_file=$(find "$out/lib/opencode/dist" -type f -name 'parser.worker.*' | sort | head -n1)
    if [ -z "$worker_file" ]; then
      echo "ERROR: bundled worker not found"
      exit 1
    fi

    main_wasm=$(printf '%s\n' "$out"/lib/opencode/dist/tree-sitter-*.wasm | sort | head -n1)
    wasm_list=$(find "$out/lib/opencode/dist" -maxdepth 1 -name 'tree-sitter-*.wasm' -print)
    for patch_file in "$worker_file" "$parser_worker_file"; do
      [ -z "$patch_file" ] && continue
      [ ! -f "$patch_file" ] && continue
      if [ -n "$wasm_list" ] && grep -q 'tree-sitter' "$patch_file"; then
        # Rewrite wasm references to absolute store paths to avoid runtime resolve failures.
        bun --bun ../../nix/scripts/patch-wasm.ts "$patch_file" "$main_wasm" $wasm_list
      fi
    done

    mkdir -p $out/lib/opencode/node_modules
    cp -r ../../node_modules/.bun $out/lib/opencode/node_modules/
    mkdir -p $out/lib/opencode/node_modules/@opentui

    # Generate and install JSON schema
    mkdir -p $out/share/opencode
    HOME=$TMPDIR bun --bun script/schema.ts $out/share/opencode/schema.json

    mkdir -p $out/bin
    makeWrapper ${bun}/bin/bun $out/bin/opencode \
      --add-flags "run" \
      --add-flags "$out/lib/opencode/dist/src/index.js" \
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
    pkgs=(
      $out/lib/opencode/node_modules/.bun/@opentui+core-*
      $out/lib/opencode/node_modules/.bun/@opentui+solid-*
      $out/lib/opencode/node_modules/.bun/@opentui+core@*
      $out/lib/opencode/node_modules/.bun/@opentui+solid@*
    )
    for pkg in "''${pkgs[@]}"; do
      if [ -d "$pkg" ]; then
        pkgName=$(basename "$pkg" | sed 's/@opentui+\([^@]*\)@.*/\1/')
        ln -sf ../.bun/$(basename "$pkg")/node_modules/@opentui/$pkgName \
          $out/lib/opencode/node_modules/@opentui/$pkgName
      fi
    done
  '';

  passthru = {
    jsonschema = "${placeholder "out"}/share/opencode/schema.json";
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
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    platforms = lib.platforms.unix;
    mainProgram = "opencode";
  };
})
