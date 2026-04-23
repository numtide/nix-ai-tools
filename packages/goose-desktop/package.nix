{
  lib,
  binutils,
  flake,
  stdenvNoCC,
  copyDesktopItems,
  electron_41,
  makeBinaryWrapper,
  makeDesktopItem,
  zstd,
  upstream,
  gooseServer,
}:

let
  desktopItem = makeDesktopItem {
    name = "goose-desktop";
    desktopName = "Goose";
    comment = "Goose desktop AI agent";
    exec = "goose-desktop";
    icon = "goose";
    categories = [
      "Development"
      "Utility"
    ];
    startupNotify = true;
  };
in
stdenvNoCC.mkDerivation {
  pname = "goose-desktop";
  version = upstream.desktopVersion;
  src = upstream.desktopDebSrc;

  nativeBuildInputs = [
    binutils
    copyDesktopItems
    makeBinaryWrapper
    zstd
  ];

  desktopItems = [ desktopItem ];

  unpackPhase = ''
    runHook preUnpack
    mkdir payload
    cd payload
    ar p "$src" data.tar.zst | tar --zstd -xf -
    cd ..
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/goose-desktop $out/bin $out/share/pixmaps

    cp -r payload/usr/lib/goose/resources $out/share/goose-desktop/
    rm -f $out/share/goose-desktop/resources/bin/goosed
    ln -s ${gooseServer}/bin/goosed $out/share/goose-desktop/resources/bin/goosed

    install -Dm644 payload/usr/share/pixmaps/goose.png $out/share/pixmaps/goose.png

    makeBinaryWrapper ${electron_41}/bin/electron $out/bin/goose-desktop \
      --add-flags $out/share/goose-desktop/resources/app.asar

    runHook postInstall
  '';

  passthru.category = "AI Coding Agents";

  meta = with lib; {
    description = "Desktop frontend for Goose, packaged against shared Goose binaries";
    homepage = "https://github.com/aaif-goose/goose";
    changelog = "https://github.com/aaif-goose/goose/releases/tag/v${upstream.desktopVersion}";
    license = licenses.asl20;
    maintainers = with flake.lib.maintainers; [ smdex ];
    mainProgram = "goose-desktop";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
  };
}
