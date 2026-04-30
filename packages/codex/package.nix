{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchurl,
  fetchzip,
  installShellFiles,
  makeWrapper,
  rustPlatform,
  pkg-config,
  openssl,
  bubblewrap,
  libcap,
  versionCheckHook,
  installShellCompletions ? stdenv.buildPlatform.canExecute stdenv.hostPlatform,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version hash cargoHash;

  # The v8 crate downloads a prebuilt static library at build time. Fetch it
  # as a fixed-output derivation so the build stays sandboxed.
  librusty_v8 = fetchurl {
    name = "librusty_v8-${versionData.librusty_v8.version}";
    url = "https://github.com/denoland/rusty_v8/releases/download/v${versionData.librusty_v8.version}/librusty_v8_release_${stdenv.hostPlatform.rust.rustcTarget}.a.gz";
    hash = versionData.librusty_v8.hashes.${stdenv.hostPlatform.system};
    meta.sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };

  # codex-realtime-webrtc pulls in livekit's webrtc-sys on macOS, whose
  # build.rs would download a ~300MB prebuilt libwebrtc archive at build
  # time. Prefetch it as a fixed-output derivation and point the crate at
  # it via LK_CUSTOM_WEBRTC so the build stays sandboxed.
  livekitWebrtcTriple =
    {
      x86_64-darwin = "mac-x64";
      aarch64-darwin = "mac-arm64";
    }
    .${stdenv.hostPlatform.system} or null;
  livekitWebrtc =
    if livekitWebrtcTriple == null then
      null
    else
      fetchzip {
        name = "livekit-webrtc-${versionData.livekit_webrtc.tag}-${livekitWebrtcTriple}";
        url = "https://github.com/livekit/rust-sdks/releases/download/${versionData.livekit_webrtc.tag}/webrtc-${livekitWebrtcTriple}-release.zip";
        hash = versionData.livekit_webrtc.hashes.${stdenv.hostPlatform.system};
        meta.sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
      };

  src = fetchFromGitHub {
    owner = "openai";
    repo = "codex";
    tag = "rust-v${version}";
    inherit hash;
  };
in
rustPlatform.buildRustPackage {
  pname = "codex";
  inherit version src;

  inherit cargoHash;

  sourceRoot = "source/codex-rs";

  cargoBuildFlags = [
    "--package"
    "codex-cli"
  ];

  nativeBuildInputs = [
    installShellFiles
    makeWrapper
    pkg-config
  ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [
    # Unable to find libclang: "couldn't find any valid shared libraries matching: ['libclang.dylib']
    rustPlatform.bindgenHook
  ];

  buildInputs = [ openssl ] ++ lib.optionals stdenv.hostPlatform.isLinux [ libcap ];

  env = {
    RUSTY_V8_ARCHIVE = librusty_v8;
  }
  // lib.optionalAttrs (livekitWebrtc != null) {
    LK_CUSTOM_WEBRTC = livekitWebrtc;
  };

  preBuild = ''
    # Upstream sets fat LTO + codegen-units=1 in [profile.release] purely to
    # shrink the shipped binary (openai/codex#1411). With ~1.2k crates and 80
    # workspace members, codegen-units=1 makes each late-stage rustc hold the
    # whole crate's IR in one module (~2–2.5 GiB RSS for codex-core/-tui), so
    # `cargo -j$NIX_BUILD_CORES` peaks at ~12 GiB and OOMs our 16 GiB aarch64
    # builder. Relax both; LTO off also keeps the link step cheap.
    substituteInPlace Cargo.toml \
      --replace-fail 'lto = "fat"' 'lto = false' \
      --replace-fail 'codegen-units = 1' 'codegen-units = 16'
  '';

  postFixup = lib.optionalString stdenv.hostPlatform.isLinux ''
    wrapProgram $out/bin/codex \
      --prefix PATH : ${lib.makeBinPath [ bubblewrap ]}
  '';

  doCheck = false;

  postInstall = lib.optionalString installShellCompletions ''
    installShellCompletion --cmd codex \
      --bash <($out/bin/codex completion bash) \
      --fish <($out/bin/codex completion fish) \
      --zsh <($out/bin/codex completion zsh)
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  passthru.category = "AI Coding Agents";

  meta = {
    description = "OpenAI Codex CLI - a coding agent that runs locally on your computer";
    homepage = "https://github.com/openai/codex";
    changelog = "https://github.com/openai/codex/releases/tag/rust-v${version}";
    sourceProvenance = with lib.sourceTypes; [
      fromSource
      binaryNativeCode # librusty_v8
    ];
    license = lib.licenses.asl20;
    mainProgram = "codex";
    platforms = lib.platforms.unix;
  };
}
