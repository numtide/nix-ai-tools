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
  pname = "camofox-jo";
  npmName = "@askjo/camofox-browser";
  version = "1.5.2";

  srcWithLock = runCommand "${pname}-${version}-src-with-lock" { } ''
    mkdir -p $out
    tar -xzf ${
      fetchurl {
        url = "https://registry.npmjs.org/@askjo/camofox-browser/-/camofox-browser-${version}.tgz";
        hash = "sha256-LJcX2j/BuqW7SbNgWUvGf/OWnwy6m1U5Cc8OWQkKUWo=";
      }
    } -C $out --strip-components=1
    cp ${
      fetchurl {
        url = "https://raw.githubusercontent.com/jo-inc/camofox-browser/master/package-lock.json";
        hash = "sha256-oy+WohGP+NKEDizd0rtn4fnfluMLjihp530FVik6wvM=";
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
    hash = "sha256-AWqp/ZI4uW5MD/fn40qpQE0Lc2zjrNrcRRa1FqSCAqA=";
    fetcherVersion = 2;
  };

  makeCacheWritable = true;
  npmFlags = [ "--ignore-scripts" ];
  dontNpmBuild = true;

  nativeBuildInputs = [ makeWrapper ];

  postPatch = ''
    substituteInPlace server.js \
      --replace-fail 'const options = await launchOptions({' 'const options = await launchOptions({ ...(process.env.CAMOFOX_EXECUTABLE_PATH ? { executable_path: process.env.CAMOFOX_EXECUTABLE_PATH } : {}),'
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/{bin,lib/${pname}}

    npm prune --omit=dev

    cp -r lib node_modules package.json README.md LICENSE plugin.ts openclaw.plugin.json scripts server.js $out/lib/${pname}/

    makeWrapper ${lib.getExe nodejs} $out/bin/${pname} \
      --add-flags "$out/lib/${pname}/server.js" \
      ${lib.optionalString (camoufox != null) "--set CAMOFOX_EXECUTABLE_PATH ${lib.getExe camoufox}"}

    runHook postInstall
  '';

  passthru = {
    category = "Utilities";
    inherit npmName;
  };

  meta = {
    description = "Headless browser automation server for AI agents to visit blocked sites";
    homepage = "https://github.com/jo-inc/camofox-browser";
    changelog = "https://github.com/jo-inc/camofox-browser/releases";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryBytecode ];
    platforms = lib.platforms.all;
    mainProgram = pname;
  };
}
