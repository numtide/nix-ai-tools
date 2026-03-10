{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchurl,
  unzip,
  rustPlatform,
  pnpm_10,
  fetchPnpmDeps,
  pnpmConfigHook,
  nodejs-slim,
  pkg-config,
  cmake,
  libgit2,
  sqlite,
  llvmPackages,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData)
    version
    tag
    hash
    cargoHash
    npmDepsHash
    releaseZipHash
    ;

  src = fetchFromGitHub {
    owner = "BloopAI";
    repo = "vibe-kanban";
    rev = tag;
    inherit hash;
  };

  # Upstream's release zip contains pre-built frontend assets with the
  # react-virtuoso commercial license key already baked in by their CI.
  # We extract just the key and inject it into our own source build so
  # we don't have to store it in the repository.
  releaseZip = fetchurl {
    url = "https://github.com/BloopAI/vibe-kanban/releases/download/${tag}/vibe-kanban-${tag}.zip";
    hash = releaseZipHash;
  };

  # Phase 1: Build frontend
  # The project is a pnpm monorepo; the frontend lives at packages/local-web/
  frontend = stdenv.mkDerivation {
    pname = "vibe-kanban-frontend";
    inherit version src;

    nativeBuildInputs = [
      nodejs-slim
      pnpm_10
      pnpmConfigHook
      unzip
    ];

    pnpmDeps = fetchPnpmDeps {
      pname = "vibe-kanban-frontend";
      inherit version src;
      pnpm = pnpm_10;
      hash = npmDepsHash;
      fetcherVersion = 2;
    };

    buildPhase = ''
      runHook preBuild

      # Extract the react-virtuoso license key from upstream's pre-built
      # release assets rather than storing it in our repository.
      export VITE_PUBLIC_REACT_VIRTUOSO_LICENSE_KEY=$(
        unzip -p ${releaseZip} '*/assets/index-*.js' \
          | grep -o 'licenseKey:"[^"]*"' \
          | head -1 \
          | cut -d'"' -f2
      )

      export VITE_VK_SHARED_API_BASE="https://api.vibekanban.com"

      pnpm --filter @vibe/local-web run build
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r packages/local-web/dist/* $out/
      runHook postInstall
    '';
  };

in
# Phase 2: Build Rust with embedded frontend
rustPlatform.buildRustPackage {
  pname = "vibe-kanban";
  inherit version src cargoHash;

  cargoBuildFlags = [
    "--package"
    "server"
    "--package"
    "review"
    "--package"
    "mcp"
  ];

  nativeBuildInputs = [
    pkg-config
    cmake
    llvmPackages.libclang
  ];
  buildInputs = [
    libgit2
    sqlite
  ];

  # Copy frontend assets where rust-embed expects them
  # (crates/server references ../../packages/local-web/dist)
  preBuild = ''
    mkdir -p packages/local-web/dist
    cp -r ${frontend}/* packages/local-web/dist/
  '';

  env = {
    SQLX_OFFLINE = "true";
    LIBCLANG_PATH = "${llvmPackages.libclang.lib}/lib";
  };

  doCheck = false;

  postInstall = ''
    mv $out/bin/server $out/bin/vibe-kanban
    mv $out/bin/review $out/bin/vibe-kanban-review
    # mcp crate already outputs binary named "vibe-kanban-mcp", no rename needed
    rm -f $out/bin/generate_types
    rm -rf $out/bin/*.dSYM
  '';

  passthru.category = "Workflow & Project Management";

  meta = {
    description = "Kanban board to orchestrate AI coding agents like Claude Code, Codex, and Gemini CLI";
    homepage = "https://github.com/BloopAI/vibe-kanban";
    license = lib.licenses.asl20;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    mainProgram = "vibe-kanban";
    platforms = lib.platforms.unix;
  };
}
