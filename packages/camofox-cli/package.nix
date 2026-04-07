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
  pname = "camofox-cli";
  npmName = "camoufox-cli";
  version = "0.2.0";

  srcWithLock = runCommand "${pname}-${version}-src-with-lock" { } ''
    mkdir -p $out
    tar -xzf ${
      fetchurl {
        url = "https://registry.npmjs.org/${npmName}/-/${npmName}-${version}.tgz";
        hash = "sha256-53nqE1Jnl1kSQvlOHhlHqe7WTdBeobRfuiupHZPpcZQ=";
      }
    } -C $out --strip-components=1
    cp ${
      fetchurl {
        url = "https://raw.githubusercontent.com/Bin-Huang/camoufox-cli/main/js/package-lock.json";
        hash = "sha256-EZ2uXDIAlnr2vnN9U2BRNomIRTKvkzpFwPGtucpVOw8=";
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
    hash = "sha256-VEtU5ry9GR6Ph/ArtJ3uIk6wFIWMuXtPRag9NZvk0IY=";
    fetcherVersion = 2;
  };

  makeCacheWritable = true;
  npmFlags = [ "--ignore-scripts" ];
  dontNpmBuild = true;

  nativeBuildInputs = [ makeWrapper ];

  postPatch = ''
    substituteInPlace dist/browser.js \
      --replace-fail '        execFileSync("npx", ["camoufox-js", "path"], { stdio: "pipe" });' '        if (process.env.CAMOFOX_EXECUTABLE_PATH)
            return;
        execFileSync("npx", ["camoufox-js", "path"], { stdio: "pipe" });'
    substituteInPlace dist/browser.js \
      --replace-fail '        const launchOpts = { headless };' '        const launchOpts = { headless };
        if (process.env.CAMOFOX_EXECUTABLE_PATH)
            launchOpts.executable_path = process.env.CAMOFOX_EXECUTABLE_PATH;'
    substituteInPlace dist/cli.js \
      --replace-fail '        execFileSync("npx", ["camoufox-js", "fetch"], { stdio: "inherit" });' '        if (process.env.CAMOFOX_EXECUTABLE_PATH) {
            console.error("[camoufox-cli] Browser managed by Nix wrapper.");
            return;
        }
        execFileSync("npx", ["camoufox-js", "fetch"], { stdio: "inherit" });'
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/{bin,lib/${pname}}

    npm prune --omit=dev

    cp -r dist node_modules package.json LICENSE $out/lib/${pname}/

    makeWrapper ${lib.getExe nodejs} $out/bin/${pname} \
      --add-flags "$out/lib/${pname}/dist/cli.js" \
      ${lib.optionalString (camoufox != null) "--set CAMOFOX_EXECUTABLE_PATH ${lib.getExe camoufox}"}

    runHook postInstall
  '';

  passthru = {
    category = "Utilities";
    inherit npmName;
  };

  meta = {
    description = "Anti-detect browser automation CLI for AI agents powered by Camoufox";
    homepage = "https://github.com/Bin-Huang/camoufox-cli";
    changelog = "https://github.com/Bin-Huang/camoufox-cli/releases";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryBytecode ];
    platforms = lib.platforms.all;
    mainProgram = pname;
  };
}
