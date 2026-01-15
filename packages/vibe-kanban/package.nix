{
  lib,
  stdenv,
  fetchFromGitHub,
  rustPlatform,
  pnpm_10,
  fetchPnpmDeps,
  pnpmConfigHook,
  nodejs-slim,
  pkg-config,
  openssl,
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
    ;

  src = fetchFromGitHub {
    owner = "BloopAI";
    repo = "vibe-kanban";
    rev = tag;
    inherit hash;
  };

  # Phase 1: Build frontend
  frontend = stdenv.mkDerivation {
    pname = "vibe-kanban-frontend";
    inherit version src;

    nativeBuildInputs = [
      nodejs-slim
      pnpm_10
      pnpmConfigHook
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
      cd frontend
      pnpm build
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r dist/* $out/
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
  ];

  nativeBuildInputs = [
    pkg-config
    llvmPackages.libclang
  ];
  buildInputs = [
    openssl
    libgit2
    sqlite
  ];

  # Copy frontend assets before Rust build
  preBuild = ''
    mkdir -p frontend/dist
    cp -r ${frontend}/* frontend/dist/
  '';

  env = {
    SQLX_OFFLINE = "true";
    LIBCLANG_PATH = "${llvmPackages.libclang.lib}/lib";
  };

  doCheck = false;

  postInstall = ''
    mv $out/bin/server $out/bin/vibe-kanban
    mv $out/bin/mcp_task_server $out/bin/vibe-kanban-mcp
    mv $out/bin/review $out/bin/vibe-kanban-review
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
