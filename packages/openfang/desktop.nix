{
  lib,
  flake,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  openssl,
  wrapGAppsHook3,
  makeWrapper,
  # Linux GUI dependencies
  at-spi2-atk,
  cairo,
  gdk-pixbuf,
  glib,
  gtk3,
  harfbuzz,
  libayatana-appindicator,
  librsvg,
  libsoup_3,
  pango,
  webkitgtk_4_1,
  # Desktop file integration
  copyDesktopItems,
  makeDesktopItem,
  # Runtime tools
  playwright,
  chromium,
  yt-dlp,
  nodejs,
  claude-code,
}:

rustPlatform.buildRustPackage rec {
  pname = "openfang-desktop";
  version = "0.3.26";

  src = fetchFromGitHub {
    owner = "RightNow-AI";
    repo = "openfang";
    tag = "v${version}";
    hash = "sha256-UMDGBpBZQs9bF9TnMxJtMw/tbTpg3P85NJEPK8rboUo=";
  };

  cargoHash = "sha256-lJVUXJocnGmvYgaWz78i2z096PCoPHf52KEo/tbvXnI=";

  # Build only the desktop crate
  buildAndTestSubdir = "crates/openfang-desktop";

  nativeBuildInputs = [
    pkg-config
    wrapGAppsHook3
    copyDesktopItems
    makeWrapper
  ];

  buildInputs = [
    openssl
    # Tauri 2.0 Linux dependencies
    at-spi2-atk
    cairo
    gdk-pixbuf
    glib
    gtk3
    harfbuzz
    libayatana-appindicator
    librsvg
    libsoup_3
    pango
    webkitgtk_4_1
  ];

  # Fix WebKit rendering issues on NixOS
  env.WEBKIT_DISABLE_DMABUF_RENDERER = "1";

  # Tests require network access and external dependencies
  doCheck = false;

  # GUI-only app - can't run version check without display
  doInstallCheck = false;

  # Add rpath for dlopen'd libayatana-appindicator (tray icon support)
  # and wrap with runtime tools in PATH
  postFixup = ''
    patchelf --add-rpath "${lib.makeLibraryPath [ libayatana-appindicator ]}" \
      $out/bin/.openfang-desktop-wrapped

    wrapProgram $out/bin/openfang-desktop \
      --prefix PATH : "${
        lib.makeBinPath [
          playwright
          chromium
          yt-dlp
          nodejs
          claude-code
        ]
      }"
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "openfang";
      desktopName = "OpenFang";
      comment = "Open-source Agent Operating System";
      exec = "openfang-desktop";
      icon = "openfang";
      categories = [ "Development" ];
      startupNotify = true;
    })
  ];

  postInstall = ''
    # Install icons from the tauri bundle config
    for size in 32 128; do
      install -Dm644 $src/crates/openfang-desktop/icons/''${size}x''${size}.png \
        $out/share/icons/hicolor/''${size}x''${size}/apps/openfang.png || true
    done
    install -Dm644 $src/crates/openfang-desktop/icons/icon.png \
      $out/share/icons/hicolor/256x256/apps/openfang.png || true
  '';

  passthru.category = "AI Assistants";

  meta = with lib; {
    description = "Native desktop application for the OpenFang Agent OS (Tauri 2.0)";
    homepage = "https://openfang.sh";
    changelog = "https://github.com/RightNow-AI/openfang/releases/tag/v${version}";
    downloadPage = "https://github.com/RightNow-AI/openfang/releases";
    license = with licenses; [
      asl20
      mit
    ];
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ ];
    mainProgram = "openfang-desktop";
    # webkitgtk_4_1 is Linux-only
    platforms = platforms.linux;
  };
}
