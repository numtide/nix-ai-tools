{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  chromium,
  makeBinaryWrapper,
  fetchNpmDepsWithPackuments,
  nodejs-slim,
  npmConfigHook,
  rustPlatform,
  stdenv,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData)
    version
    hash
    cargoHash
    npmDepsHash
    ;

  src = fetchFromGitHub {
    owner = "vercel-labs";
    repo = "agent-browser";
    rev = "v${version}";
    inherit hash;
  };

  # Build the native Rust CLI binary separately
  agent-browser-native-binary = rustPlatform.buildRustPackage {
    pname = "agent-browser-native-binary";
    inherit version src cargoHash;

    sourceRoot = "source/cli";

    meta = {
      description = "Native Rust CLI for agent-browser";
      license = lib.licenses.asl20;
      platforms = lib.platforms.unix;
    };
  };
in
buildNpmPackage {
  inherit npmConfigHook version src;
  pname = "agent-browser";

  npmDeps = fetchNpmDepsWithPackuments {
    inherit src;
    name = "agent-browser-${version}-npm-deps";
    hash = npmDepsHash;
    fetcherVersion = 2;
    postPatch = ''
      cp ${./package-lock.json} package-lock.json
    '';
  };
  makeCacheWritable = true;

  nativeBuildInputs = [ makeBinaryWrapper ];

  # On Linux, bundle chromium; on macOS, use system-installed Chrome
  buildInputs = [ agent-browser-native-binary ] ++ lib.optional stdenv.isLinux chromium;

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  # Skip the postinstall script that downloads Chromium
  # We'll use the Nix-provided chromium instead
  npmFlags = [ "--ignore-scripts" ];

  buildPhase = ''
    runHook preBuild
    npm run build
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/agent-browser
    cp -r dist node_modules scripts $out/share/agent-browser/

    mkdir -p $out/etc/agent-browser
    cp -r skills $out/etc/agent-browser/

    mkdir -p $out/bin
    # Copy the native binary to our bin directory
    cp ${agent-browser-native-binary}/bin/agent-browser $out/bin/.agent-browser-unwrapped

    # Create symlinks so the Rust CLI can find daemon.js
    # The CLI searches for: exe_dir/../dist/daemon.js
    ln -s $out/share/agent-browser/dist $out/dist
    ln -s $out/share/agent-browser/node_modules $out/node_modules

    # Create wrapper that sets up PATH and environment
    makeWrapper $out/bin/.agent-browser-unwrapped $out/bin/agent-browser \
      --prefix PATH : ${lib.makeBinPath [ nodejs-slim ]} \
      ${lib.optionalString stdenv.isLinux "--set AGENT_BROWSER_EXECUTABLE_PATH ${chromium}/bin/chromium"}

    runHook postInstall
  '';

  doInstallCheck = false;

  passthru.category = "Utilities";

  meta = {
    description = "Headless browser automation CLI for AI agents";
    homepage = "https://github.com/vercel-labs/agent-browser";
    license = lib.licenses.asl20;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    platforms = lib.platforms.all;
    mainProgram = "agent-browser";
  };
}
