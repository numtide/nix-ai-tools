{
  lib,
  stdenv,
  fetchFromGitHub,
  bun2nix,
  bun,
  rustc,
  cargo,
  rustPlatform,
  pkg-config,
  makeWrapper,
  autoPatchelfHook,
  zlib,
  libclang,
  zig,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version hash cargoHash;
  platformsBySystem = {
    aarch64-darwin = {
      bunTarget = "bun-darwin-arm64";
      nativeLib = "libpi_natives.dylib";
      nodeTag = "darwin-arm64";
    };
    aarch64-linux = {
      bunTarget = "bun-linux-arm64";
      nativeLib = "libpi_natives.so";
      nodeTag = "linux-arm64";
    };
    x86_64-darwin = {
      bunTarget = "bun-darwin-x64";
      nativeLib = "libpi_natives.dylib";
      nodeTag = "darwin-x64";
    };
    x86_64-linux = {
      bunTarget = "bun-linux-x64-modern";
      nativeLib = "libpi_natives.so";
      nodeTag = "linux-x64";
    };
  };
  platform =
    platformsBySystem.${stdenv.hostPlatform.system}
      or (throw "Unsupported platform for omp: ${stdenv.hostPlatform.system}");
  rustTarget = stdenv.hostPlatform.rust.rustcTarget;
  rustTargetEnv = "CARGO_TARGET_${
    lib.toUpper (builtins.replaceStrings [ "-" ] [ "_" ] rustTarget)
  }_RUSTFLAGS";
  glimmerRustFlags = lib.concatStringsSep " " [
    "-Clink-arg=-Wl,-u,tree_sitter_glimmer_external_scanner_create"
    "-Clink-arg=-Wl,-u,tree_sitter_glimmer_external_scanner_destroy"
    "-Clink-arg=-Wl,-u,tree_sitter_glimmer_external_scanner_reset"
    "-Clink-arg=-Wl,-u,tree_sitter_glimmer_external_scanner_scan"
    "-Clink-arg=-Wl,-u,tree_sitter_glimmer_external_scanner_serialize"
    "-Clink-arg=-Wl,-u,tree_sitter_glimmer_external_scanner_deserialize"
  ];

  src = fetchFromGitHub {
    owner = "can1357";
    repo = "oh-my-pi";
    tag = "v${version}";
    inherit hash;
  };
in
stdenv.mkDerivation {
  pname = "omp";
  inherit version src;

  cargoDeps = rustPlatform.fetchCargoVendor {
    name = "omp-${version}-cargo-vendor";
    inherit src;
    hash = cargoHash;
  };

  nativeBuildInputs = [
    bun2nix.hook
    bun
    rustc
    cargo
    rustPlatform.cargoSetupHook
    pkg-config
    makeWrapper
    zig
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    stdenv.cc.cc.lib
    zlib
  ];

  # smallvec's `specialization` feature requires nightly Rust.
  # RUSTC_BOOTSTRAP=1 enables nightly features on stable rustc.
  env = {
    RUSTC_BOOTSTRAP = 1;
    ${rustTargetEnv} = glimmerRustFlags;
  };

  bunDeps = bun2nix.fetchBunDeps {
    bunNix = ./bun.nix;
  };

  # We handle build and install ourselves
  dontUseBunBuild = true;
  dontUseBunInstall = true;
  dontRunLifecycleScripts = true;

  # bun compile embeds JS in the binary; stripping would break it
  dontStrip = true;

  postPatch = ''
    # bun resolves caret-range specifiers via the npm registry even when the
    # pinned version is already in the local cache. In the Nix sandbox this
    # fails because the network is blocked. Strip ^ and ~ prefixes so bun
    # treats them as exact.
    for f in package.json packages/*/package.json; do
      if [ -f "$f" ]; then
        sed -i 's/: "\^/: "/g; s/: "~/: "/g' "$f"
      fi
    done
    sed -i 's/: "\^/: "/g; s/: "~/: "/g' bun.lock

    # swarm-extension declares a peerDependency on @oh-my-pi/pi-coding-agent
    # with a hard-coded major (e.g. ^13) that upstream forgot to bump for the
    # v14 release. With the workspace package now at 14.x bun cannot satisfy
    # the constraint locally and falls back to the npm registry, which is
    # unreachable in the sandbox. Rewrite it to the workspace reference.
    sed -i 's|"@oh-my-pi/pi-coding-agent": "[0-9][^"]*"|"@oh-my-pi/pi-coding-agent": "workspace:*"|' \
      packages/swarm-extension/package.json bun.lock

    # Reset the stats embedded client bundle to the placeholder so we don't
    # need to build the full React dashboard.
    cat > packages/stats/src/embedded-client.generated.txt <<'PLACEHOLDER'
    export const EMBEDDED_CLIENT_ARCHIVE_TAR_GZ_BASE64 = "";
    PLACEHOLDER
  '';

  buildPhase = ''
    runHook preBuild

    # Native node modules like @napi-rs/cli need libstdc++ at build time
    ${lib.optionalString stdenv.hostPlatform.isLinux ''
      export LD_LIBRARY_PATH="${lib.makeLibraryPath [ stdenv.cc.cc.lib ]}"
    ''}

    # bindgen (used by zlob crate) needs libclang
    export LIBCLANG_PATH="${libclang.lib}/lib"

    # Build the Rust native addon
    echo "Building Rust native addon..."
    cargo build --release -p pi-natives --target ${rustTarget} --target-dir target

    # Install the native addon where the JS code expects it
    mkdir -p packages/natives/native
    cp target/${rustTarget}/release/${platform.nativeLib} \
       packages/natives/native/pi_natives.${platform.nodeTag}.node

    # Generate the napi type definitions and JS loader by running the
    # napi CLI from node_modules
    napiBin="$(pwd)/node_modules/.bin/napi"
    if [ -x "$napiBin" ]; then
      "$napiBin" build \
        --manifest-path crates/pi-natives/Cargo.toml \
        --package-json-path packages/natives/package.json \
        --platform \
        --no-js \
        --dts index.d.ts \
        -o packages/natives/native \
        --release \
        || echo "napi CLI post-processing failed; using cargo output directly"
    fi

    # Generate runtime enum exports from const enums in the type definitions
    if [ -f packages/natives/scripts/gen-enums.ts ] && \
       [ -f packages/natives/native/index.d.ts ]; then
      bun packages/natives/scripts/gen-enums.ts || true
    fi

    # Generate the docs index (prepack script in coding-agent)
    echo "Generating docs index..."
    bun packages/coding-agent/scripts/generate-docs-index.ts

    # Compile the standalone binary
    echo "Compiling standalone binary..."
    bun build --compile \
      --define PI_COMPILED=true \
      --external mupdf \
      --target="${platform.bunTarget}" \
      --root . \
      ./packages/coding-agent/src/cli.ts \
      --outfile dist/omp

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/omp $out/bin
    cp dist/omp $out/lib/omp/omp
    # native.ts probes dirname(process.execPath) for the addon. On x64 it
    # looks for -modern / -baseline / plain in that order, on arm64 only
    # the plain name. Ship the plain name so both arches resolve it.
    cp packages/natives/native/pi_natives.${platform.nodeTag}.node $out/lib/omp/

    makeWrapper $out/lib/omp/omp $out/bin/omp \
      --set PI_SKIP_VERSION_CHECK 1 \
    ${lib.optionalString stdenv.hostPlatform.isLinux "--prefix LD_LIBRARY_PATH : ${
      lib.makeLibraryPath [
        zlib
        stdenv.cc.cc.lib
      ]
    }"}

    runHook postInstall
  '';

  passthru.category = "AI Coding Agents";

  meta = with lib; {
    description = "A terminal-based coding agent with multi-model support";
    homepage = "https://github.com/can1357/oh-my-pi";
    changelog = "https://github.com/can1357/oh-my-pi/releases/tag/v${version}";
    license = licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with maintainers; [ aldoborrero ];
    mainProgram = "omp";
    platforms = builtins.attrNames platformsBySystem;
  };
}
