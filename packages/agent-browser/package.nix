{
  lib,
  fetchFromGitHub,
  chromium,
  makeBinaryWrapper,
  fetchPnpmDeps,
  nodejs-slim,
  nodejs,
  pnpm_10,
  pnpmConfigHook,
  rustPlatform,
  stdenv,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData)
    version
    hash
    cargoHash
    pnpmDepsHash
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

    # Auth/credential tests require a keyring unavailable in the sandbox
    doCheck = false;

    meta = {
      description = "Native Rust CLI for agent-browser";
      license = lib.licenses.asl20;
      platforms = lib.platforms.unix;
    };
  };
in
stdenv.mkDerivation {
  inherit version src;
  pname = "agent-browser";

  pnpmDeps = fetchPnpmDeps {
    inherit src;
    pname = "agent-browser";
    inherit version;
    pnpm = pnpm_10;
    hash = pnpmDepsHash;
    fetcherVersion = 2;
  };

  nativeBuildInputs = [
    makeBinaryWrapper
    nodejs
    pnpm_10
    pnpmConfigHook
  ];

  # On Linux, bundle chromium; on macOS, use system-installed Chrome
  buildInputs = [ agent-browser-native-binary ] ++ lib.optional stdenv.isLinux chromium;

  buildPhase = ''
    runHook preBuild
    pnpm run build
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

  passthru = {
    category = "Utilities";
    # Exposed for the update script to calculate cargoHash independently
    inherit agent-browser-native-binary;
  };

  meta = {
    description = "Headless browser automation CLI for AI agents";
    homepage = "https://github.com/vercel-labs/agent-browser";
    changelog = "https://github.com/vercel-labs/agent-browser/releases/tag/v${version}";
    license = lib.licenses.asl20;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    platforms = lib.platforms.all;
    mainProgram = "agent-browser";
  };
}
