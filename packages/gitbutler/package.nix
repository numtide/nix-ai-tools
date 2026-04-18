{
  lib,
  flake,
  stdenv,
  cacert,
  cargo-tauri,
  cmake,
  curl,
  dart-sass,
  desktop-file-utils,
  fetchFromGitHub,
  fetchPnpmDeps,
  glib-networking,
  jq,
  libgit2,
  makeBinaryWrapper,
  moreutils,
  nodejs,
  openssl,
  pkg-config,
  pnpm,
  pnpmConfigHook,
  rust,
  rustPlatform,
  turbo,
  webkitgtk_4_1,
  wrapGAppsHook4,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "gitbutler";
  version = "0.19.8";

  src = fetchFromGitHub {
    owner = "gitbutlerapp";
    repo = "gitbutler";
    tag = "release/${finalAttrs.version}";
    hash = "sha256-qYPXZ28FpYiQ7+T1XOPuBbsdT82UDbQxxaLmKyYOCTc=";
  };

  # Pin the user-facing version into the Tauri release config and disable the
  # built-in updater so the packaged app doesn't try to self-update. The
  # `externalBin` rewrite keeps only the git helper shims that we actually ship.
  postPatch = ''
    tauriConfRelease="crates/gitbutler-tauri/tauri.conf.release.json"
    jq '.
        | (.version = "${finalAttrs.version}")
        | (.bundle.createUpdaterArtifacts = false)
        | (.bundle.externalBin = ["gitbutler-git-setsid", "gitbutler-git-askpass"])
      ' "$tauriConfRelease" | sponge "$tauriConfRelease"

    substituteInPlace apps/desktop/src/lib/backend/tauri.ts \
      --replace-fail 'checkUpdate = tauriCheck;' 'checkUpdate = () => null;'
  '';

  cargoHash = "sha256-Ea3U7noKcHhy1wUExwY2tdi3fbAcJLb6bVv6wag5LGI=";

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    fetcherVersion = 2;
    hash = "sha256-BJcvcMHKHpm5HJZlZaqGz/5xYT1eNOMcg5MI2kOmebM=";
  };

  nativeBuildInputs = [
    cacert # required by turbo
    cargo-tauri.hook
    cmake # required by the `zlib-sys` crate
    dart-sass
    desktop-file-utils
    jq
    moreutils
    nodejs
    pkg-config
    pnpm
    pnpmConfigHook
    turbo
    wrapGAppsHook4
  ]
  ++ lib.optional stdenv.hostPlatform.isDarwin makeBinaryWrapper;

  buildInputs = [
    libgit2
    openssl
  ]
  ++ lib.optional stdenv.hostPlatform.isDarwin curl
  ++ lib.optionals stdenv.hostPlatform.isLinux [
    glib-networking
    webkitgtk_4_1
  ];

  tauriBuildFlags = [
    "--config"
    "crates/gitbutler-tauri/tauri.conf.release.json"
  ];

  # The workspace test suite requires git fixtures, network access and the
  # full Tauri stack; upstream CI runs these separately.
  doCheck = false;

  env = {
    # Let `crates/gitbutler-tauri/inject-git-binaries.sh` find the Rust target dir.
    TRIPLE_OVERRIDE = rust.envVars.rustHostPlatformSpec;

    # `fetchPnpmDeps` / `pnpmConfigHook` pin their own pnpm; disable corepack's
    # strict engine check so it doesn't reject that pnpm.
    COREPACK_ENABLE_STRICT = 0;

    # Task tracing requires Tokio built with this cfg.
    RUSTFLAGS = "--cfg tokio_unstable";

    TUBRO_BINARY_PATH = lib.getExe turbo;
    TURBO_TELEMETRY_DISABLED = 1;

    OPENSSL_NO_VENDOR = true;
    LIBGIT2_NO_VENDOR = 1;
  };

  preBuild = ''
    # Force the bundled sass-embedded wrapper to invoke our dart-sass binary
    # instead of the prebuilt one it ships with.
    substituteInPlace node_modules/.pnpm/sass-embedded@*/node_modules/sass-embedded/dist/lib/src/compiler-path.js \
      --replace-fail 'compilerCommand = (() => {' 'compilerCommand = (() => { return ["${lib.getExe dart-sass}"];'

    turbo run --filter @gitbutler/svelte-comment-injector build
    pnpm build:desktop -- --mode production
  '';

  postInstall =
    lib.optionalString stdenv.hostPlatform.isDarwin ''
      makeBinaryWrapper $out/Applications/GitButler.app/Contents/MacOS/gitbutler-tauri $out/bin/gitbutler-tauri
    ''
    + lib.optionalString stdenv.hostPlatform.isLinux ''
      desktop-file-edit \
        --set-comment "A Git client for simultaneous branches on top of your existing workflow." \
        --set-key="Keywords" --set-value="git;" \
        --set-key="StartupWMClass" --set-value="GitButler" \
        $out/share/applications/GitButler.desktop
    '';

  passthru.category = "Workflow & Project Management";

  meta = with lib; {
    description = "Git client for simultaneous branches on top of your existing workflow";
    homepage = "https://gitbutler.com";
    changelog = "https://github.com/gitbutlerapp/gitbutler/releases/tag/release/${finalAttrs.version}";
    license = licenses.fsl11Mit;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ mic92 ];
    mainProgram = "gitbutler-tauri";
    platforms = platforms.linux ++ platforms.darwin;
  };
})
