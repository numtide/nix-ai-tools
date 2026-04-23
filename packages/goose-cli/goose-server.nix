{
  lib,
  flake,
  binutils,
  stdenvNoCC,
  zstd,
  upstream,
}:

stdenvNoCC.mkDerivation {
  pname = "goose-server";
  version = upstream.desktopVersion;

  src = upstream.cliBinarySrc;
  desktopSrc = upstream.desktopDebSrc;

  nativeBuildInputs = [
    binutils
    zstd
  ];

  unpackPhase = ''
    runHook preUnpack
    mkdir -p cli
    tar -xzf "$src" -C cli

    mkdir -p desktop
    cd desktop
    ar p "$desktopSrc" data.tar.zst | tar --zstd -xf -
    cd ..
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    install -Dm755 cli/goose $out/bin/goose
    install -Dm755 desktop/usr/lib/goose/resources/bin/goosed $out/bin/goosed

    runHook postInstall
  '';

  meta = with lib; {
    description = "Shared Goose backend binaries for the TypeScript CLI and desktop packages";
    homepage = "https://github.com/aaif-goose/goose";
    changelog = "https://github.com/aaif-goose/goose/releases/tag/v${upstream.desktopVersion}";
    license = licenses.asl20;
    maintainers = with flake.lib.maintainers; [ smdex ];
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    mainProgram = "goose";
  };
}
