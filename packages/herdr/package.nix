{
  lib,
  stdenv,
  flake,
  fetchFromGitHub,
  rustPlatform,
  zig_0_15,
  xcbuild,
  cctools,
  installShellFiles,
  libnotify,
  versionCheckHook,
  versionCheckHomeHook,
}:

# build.rs shells out to `zig build` to compile vendored libghostty-vt.
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "herdr";
  version = "0.9.0";

  src = fetchFromGitHub {
    owner = "herdrdev";
    repo = "herdr";
    tag = "v${finalAttrs.version}";
    hash = "sha256-SUYF4bbaYwNgoe498VoCUzuLPcjBLQXR0o0DWjjoSnI=";
  };

  cargoHash = "sha256-CW/SF/cAPDv47gS5B7XbVZEE6LC9F1a2I1TLTJ4AWdw=";

  # Pre-fetched Zig package cache for the vendored libghostty-vt, so zig can
  # build offline.  fetchDeps is a fixed-output derivation, so this does not
  # require import-from-derivation (disabled repo-wide).
  zigDeps = zig_0_15.fetchDeps {
    inherit (finalAttrs) pname version;
    src = "${finalAttrs.src}/vendor/libghostty-vt";
    fetchAll = true;
    hash = "sha256-PnM+hZIlLyQwK8vJgd/Bhjt1lNIz06T8FahwliRmMrY=";
  };

  nativeBuildInputs = [
    zig_0_15
    installShellFiles
  ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [
    # zig's macOS SDK detection shells out to xcode-select/xcrun; xcbuild
    # provides nix-native shims that answer with the nixpkgs apple-sdk.
    xcbuild
    # libghostty-vt's CombineArchivesStep runs `libtool` on Darwin.
    cctools
  ];

  # zig's setup hook overrides buildPhase/installPhase with `zig build`,
  # but here zig is only invoked indirectly from build.rs.  Keep cargo's
  # phases.
  dontUseZigBuild = true;
  dontUseZigInstall = true;
  dontUseZigCheck = true;
  dontUseZigConfigure = true;

  # build.rs passes an explicit -Dtarget that zig treats as a cross target,
  # so build-time helper executables (uucode_build_tables) get linked against
  # the FHS dynamic loader path which doesn't exist in the sandbox.  Drop the
  # flag so zig uses the native target and picks up the wrapped libc paths,
  # but keep Zig's CPU baseline explicit to avoid build-host CPU features
  # leaking into the output.
  postPatch = ''
    substituteInPlace build.rs \
      --replace-fail '.arg("build")' '.arg("build")
          .arg("-Dcpu=baseline")' \
      --replace-fail '.arg(format!("-Dtarget={zig_target}"))' ""
  ''
  + lib.optionalString stdenv.hostPlatform.isLinux ''
    substituteInPlace src/platform/linux.rs \
      --replace-fail 'let mut cmd = command("notify-send");' \
        'let mut cmd = command("${libnotify}/bin/notify-send");'
  '';

  preBuild = ''
    export ZIG_GLOBAL_CACHE_DIR="$TMPDIR/zig-global-cache"
    export ZIG_LOCAL_CACHE_DIR="$TMPDIR/zig-local-cache"
    mkdir -p "$ZIG_GLOBAL_CACHE_DIR" "$ZIG_LOCAL_CACHE_DIR"
    cp -rL ${finalAttrs.zigDeps} "$ZIG_GLOBAL_CACHE_DIR/p"
    chmod -R u+w "$ZIG_GLOBAL_CACHE_DIR/p"
  '';

  # Tests spawn PTYs / interact with the terminal and don't work in the
  # sandbox.
  doCheck = false;

  postInstall =
    lib.optionalString (stdenv.buildPlatform.canExecute stdenv.hostPlatform) ''
      installShellCompletion --cmd herdr \
        --bash <("$out/bin/herdr" completion bash) \
        --fish <("$out/bin/herdr" completion fish) \
        --zsh <("$out/bin/herdr" completion zsh)
    ''
    # Ship the per-agent hook/plugin sources so users can wire them up
    # declaratively (e.g. home-manager) instead of running `herdr integrate`.
    + ''
      install -d "$out/share/herdr"
      cp -r src/integration/assets "$out/share/herdr/integrations"
      find "$out/share/herdr/integrations" -name '*.test.ts' -delete
    '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];

  passthru.category = "Workflow & Project Management";

  meta = {
    description = "Terminal workspace manager for AI coding agents";
    homepage = "https://herdr.dev";
    changelog = "https://github.com/herdrdev/herdr/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.asl20;
    maintainers = with flake.lib.maintainers; [ murlakatam ];
    mainProgram = "herdr";
    sourceProvenance = [ lib.sourceTypes.fromSource ];
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
})
