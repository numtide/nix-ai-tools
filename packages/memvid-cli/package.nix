{
  lib,
  flake,
  stdenv,
  fetchzip,
  makeWrapper,
  autoPatchelfHook,
  libx11,
  libxext,
  libxi,
  libxrender,
  libxtst,
  openssl,
  zlib,
  alsa-lib,
}:

stdenv.mkDerivation rec {
  pname = "memvid-cli";
  version = "2.0.159";

  src = fetchzip {
    url = "https://registry.npmjs.org/@memvid/cli-linux-x64/-/cli-linux-x64-${version}.tgz";
    hash = "sha256-BiqygCVYkoQq2vqmI6DE0ME9t99wb6pZZe/NKkjCXis=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    alsa-lib
    libx11
    libxext
    libxi
    libxrender
    libxtst
    openssl
    stdenv.cc.cc.lib
    zlib
  ];

  installPhase = ''
    runHook preInstall

    install -d $out/libexec/memvid-cli
    cp -R $src/. $out/libexec/memvid-cli/
    chmod -R u+w $out/libexec/memvid-cli
    chmod 755 $out/libexec/memvid-cli/memvid

    for shared_object in $out/libexec/memvid-cli/*.so; do
      chmod 755 "$shared_object"
    done

    autoPatchelf $out/libexec/memvid-cli

    makeWrapper $out/libexec/memvid-cli/memvid $out/bin/memvid \
      --prefix LD_LIBRARY_PATH : "$out/libexec/memvid-cli"

    runHook postInstall
  '';

  doInstallCheck = true;

  installCheckPhase = ''
    runHook preInstallCheck

    tmp_home=$(mktemp -d)
    tmp_cache=$(mktemp -d)
    HOME="$tmp_home" XDG_CACHE_HOME="$tmp_cache" $out/bin/memvid --help > /dev/null

    runHook postInstallCheck
  '';

  passthru.category = "Utilities";

  meta = with lib; {
    description = "AI memory CLI - crash-safe, single-file storage with semantic search";
    homepage = "https://memvid.com";
    changelog = "https://github.com/memvid/memvid/releases";
    license = licenses.asl20;
    sourceProvenance = with sourceTypes; [
      binaryNativeCode
    ];
    maintainers = with flake.lib.maintainers; [ ypares ];
    mainProgram = "memvid";
    platforms = [ "x86_64-linux" ];
  };
}
