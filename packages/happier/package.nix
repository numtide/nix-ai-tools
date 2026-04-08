{
  lib,
  stdenv,
  fetchurl,
  fetchYarnDeps,
  fetchzip,
  jq,
  makeWrapper,
  nodejs,
  yarnConfigHook,
  ...
}:

let
  pin = lib.importJSON ./hashes.json;
  yarnLock = fetchurl {
    url = "https://raw.githubusercontent.com/happier-dev/happier/${pin.yarnLockCommit}/yarn.lock";
    hash = pin.yarnLockHash;
  };
  archivePlatformDir =
    if stdenv.hostPlatform.isDarwin then
      if stdenv.hostPlatform.isAarch64 then
        "arm64-darwin"
      else if stdenv.hostPlatform.isx86_64 then
        "x64-darwin"
      else
        throw "Unsupported CPU for happier tool archives: ${stdenv.hostPlatform.parsed.cpu.name}"
    else if stdenv.hostPlatform.isLinux then
      if stdenv.hostPlatform.isAarch64 then
        "arm64-linux"
      else if stdenv.hostPlatform.isx86_64 then
        "x64-linux"
      else
        throw "Unsupported CPU for happier tool archives: ${stdenv.hostPlatform.parsed.cpu.name}"
    else
      throw "Unsupported platform for happier tool archives: ${stdenv.hostPlatform.system}";
in
stdenv.mkDerivation (finalAttrs: {
  pname = "happier";
  inherit (pin) version;

  src = fetchzip {
    url = "https://registry.npmjs.org/@happier-dev/cli/-/cli-${finalAttrs.version}.tgz";
    hash = pin.srcHash;
  };

  postPatch = ''
    install -m 644 ${yarnLock} yarn.lock

    mkdir -p bundled-node_modules
    cp -a node_modules/@happier-dev bundled-node_modules/
    rm -rf node_modules

    # The published tarball already contains the built CLI, but it also carries
    # Yarn resolutions from the monorepo workspace root. As a standalone package
    # those resolutions become active again, while the release lockfile only pins
    # the actually resolved graph. Drop them so offline install follows the lock.
    jq 'del(.resolutions)' package.json > package.json.new
    mv package.json.new package.json
  '';

  yarnOfflineCache = fetchYarnDeps {
    inherit yarnLock;
    hash = pin.yarnOfflineHash;
  };

  nativeBuildInputs = [
    jq
    makeWrapper
    nodejs
    yarnConfigHook
  ];

  buildPhase = ''
    runHook preBuild

    mkdir -p node_modules/@happier-dev
    cp -a bundled-node_modules/@happier-dev/. node_modules/@happier-dev/
    rm -rf bundled-node_modules

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    pkgDir=$out/lib/node_modules/@happier-dev/cli
    mkdir -p $pkgDir

    cp -a README.md bin dist node_modules package-dist package.json scripts tools $pkgDir/

    test -f $pkgDir/bin/happier.mjs
    test -f $pkgDir/bin/happier-mcp.mjs
    test -f $pkgDir/node_modules/@happier-dev/protocol/package.json

    archivesDir=$pkgDir/tools/archives
    test -f "$archivesDir/difftastic-${archivePlatformDir}.tar.gz"
    test -f "$archivesDir/ripgrep-${archivePlatformDir}.tar.gz"
    for archive in "$archivesDir"/*.tar.gz; do
      case "$(basename "$archive")" in
        difftastic-${archivePlatformDir}.tar.gz|ripgrep-${archivePlatformDir}.tar.gz)
          ;;
        *)
          rm -f "$archive"
          ;;
      esac
    done

    rm -rf $out/bin
    mkdir -p $out/bin

    makeWrapper ${lib.getExe nodejs} $out/bin/happier \
      --add-flags "$pkgDir/bin/happier.mjs"
    makeWrapper ${lib.getExe nodejs} $out/bin/happier-mcp \
      --add-flags "$pkgDir/bin/happier-mcp.mjs"

    runHook postInstall
  '';

  passthru.category = "Utilities";

  meta = with lib; {
    description = "CLI for Happier, a mobile and web client for Claude Code and Codex";
    homepage = "https://github.com/happier-dev/happier";
    changelog = "https://github.com/happier-dev/happier/releases/tag/cli-v${finalAttrs.version}";
    downloadPage = "https://www.npmjs.com/package/@happier-dev/cli";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [ binaryBytecode ];
    maintainers = with maintainers; [ ];
    mainProgram = "happier";
    platforms = platforms.all;
  };
})
