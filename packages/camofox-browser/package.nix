{
  lib,
  buildNpmPackage,
  fetchurl,
  fetchNpmDepsWithPackuments,
  npmConfigHook,
  runCommand,
  makeWrapper,
  nodejs,
  camoufox ? null,
}:

let
  pname = "camofox-browser";
  version = "2.1.1";

  srcWithLock = runCommand "${pname}-${version}-src-with-lock" { } ''
    mkdir -p $out
    tar -xzf ${
      fetchurl {
        url = "https://registry.npmjs.org/${pname}/-/${pname}-${version}.tgz";
        hash = "sha256-vcNKI0sbiNQgkymTB0qYm/KaujU7qQy3wn18otdGESk=";
      }
    } -C $out --strip-components=1
    cp ${
      fetchurl {
        url = "https://raw.githubusercontent.com/redf0x1/camofox-browser/main/package-lock.json";
        hash = "sha256-tL6d3FMfgr1Zu+pHWyvFxEwGN/IWdKEZfsFnJ8UUCTI=";
      }
    } $out/package-lock.json
  '';
in
buildNpmPackage {
  inherit pname version npmConfigHook;

  src = srcWithLock;

  npmDeps = fetchNpmDepsWithPackuments {
    src = srcWithLock;
    name = "${pname}-${version}-npm-deps";
    hash = "sha256-ZjbOG7VjSy3RJQdZaoukFOkvveAKO4XBayrlM8PTrRo=";
    fetcherVersion = 2;
  };

  makeCacheWritable = true;
  npmFlags = [
    "--ignore-scripts"
    "--omit=optional"
  ];
  dontNpmBuild = true;

  nativeBuildInputs = [ makeWrapper ];

  postPatch = ''
    substituteInPlace dist/src/services/context-pool.js \
      --replace-fail 'const opts = await (0, camoufox_js_1.launchOptions)({' 'const opts = await (0, camoufox_js_1.launchOptions)({ ...(process.env.CAMOFOX_EXECUTABLE_PATH ? { executable_path: process.env.CAMOFOX_EXECUTABLE_PATH } : {}),'
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/{bin,lib/${pname}}

    npm prune --omit=dev --omit=optional

    cp -r dist bin node_modules package.json README.md CHANGELOG.md LICENSE $out/lib/${pname}/

    makeWrapper ${lib.getExe nodejs} $out/bin/camofox-browser \
      --add-flags "$out/lib/${pname}/bin/camofox-browser.js" \
      ${lib.optionalString (camoufox != null) "--set CAMOFOX_EXECUTABLE_PATH ${lib.getExe camoufox}"}

    runHook postInstall
  '';

  passthru.category = "Utilities";

  meta = {
    description = "Anti-detection browser server for AI agents powered by Camoufox";
    homepage = "https://github.com/redf0x1/camofox-browser";
    changelog = "https://github.com/redf0x1/camofox-browser/releases/tag/v${version}";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryBytecode ];
    platforms = lib.platforms.all;
    mainProgram = "camofox-browser";
  };
}
