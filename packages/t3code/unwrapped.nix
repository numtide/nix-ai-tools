{
  lib,
  flake,
  stdenv,
  fetchFromGitHub,
  fetchPnpmDeps,
  pnpm_11,
  pnpmConfigHook,
  pnpmBuildHook,
  nodejs_24,
  node-gyp,
  pkg-config,
  libsecret,
  python3,
  cacert,
  electron_43,
  makeBinaryWrapper,
  installShellFiles,
  makeDesktopItem,
  rustPlatform,
  versionCheckHook,
  versionCheckHomeHook,
  cctools,
  libicns,
  writeDarwinBundle,
  xcbuild,
}:

let
  pname = "t3code";
  version = "0.0.40";
  pnpm = pnpm_11;

  src = fetchFromGitHub {
    owner = "pingdotgg";
    repo = "t3code";
    tag = "v${version}";
    hash = "sha256-J8kXpfMfm03/DDAiWXJuANwUNDshhiUn7Lf9tV42Xfw=";
  };

  resourceMonitor = rustPlatform.buildRustPackage {
    pname = "t3code-resource-monitor";
    inherit version src;

    sourceRoot = "${src.name}/native/resource-monitor";
    cargoHash = "sha256-5cmG2daM1bVOA23gjjoalbx0fEL1hmqV6WZov0sUZp8=";
  };

  platformKey =
    {
      x86_64-linux = "linux-x64";
      aarch64-linux = "linux-arm64";
      aarch64-darwin = "darwin-arm64";
    }
    .${stdenv.hostPlatform.system};

  pnpmWorkspaces = [
    "@t3tools/monorepo"
    "t3..."
    "@t3tools/desktop..."
    "@t3tools/scripts..."
  ];

  appName = "T3 Code (Alpha)";
  desktopIcon =
    if stdenv.hostPlatform.isDarwin then
      "assets/prod/black-macos-1024.png"
    else
      "assets/prod/black-universal-1024.png";

  desktopItem = makeDesktopItem {
    name = "t3code";
    desktopName = appName;
    comment = "Control surface for coding agents";
    exec = "t3code-desktop %U";
    icon = "t3code";
    categories = [ "Development" ];
    startupWMClass = "t3code";
  };
in
stdenv.mkDerivation {
  inherit
    pname
    version
    src
    pnpmWorkspaces
    ;

  outputs = [
    "out"
    "desktop"
  ];

  strictDeps = true;
  __structuredAttrs = true;

  pnpmDeps = fetchPnpmDeps {
    inherit
      pnpm
      pname
      version
      src
      pnpmWorkspaces
      ;
    fetcherVersion = 4;
    hash = "sha256-+UsoURSM4VP+CgF1fWROBEB85EuH+iJJM/xDPFigCKk=";
  };

  nativeBuildInputs = [
    cacert
    installShellFiles
    makeBinaryWrapper
    node-gyp
    nodejs_24
    pnpm
    pnpmBuildHook
    pnpmConfigHook
    python3
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [ pkg-config ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [
    cctools.libtool
    libicns
    writeDarwinBundle
    xcbuild
  ];

  # build:desktop compiles native/browser-secret against libsecret on linux
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [ libsecret ];

  preBuild = ''
    export pnpm_config_verify_deps_before_run=false

    node scripts/update-release-package-versions.ts ${version}

    upstream_electron=$(node -p "require('./apps/desktop/package.json').dependencies.electron")
    upstream_major=''${upstream_electron#^}
    upstream_major=''${upstream_major%%.*}
    nix_major=${lib.versions.major electron_43.version}
    if (( upstream_major > nix_major )); then
      echo "error: upstream expects Electron $upstream_electron but nixpkgs provides ${electron_43.version}" >&2
      exit 1
    fi

    export npm_config_nodedir=${nodejs_24}
    export ELECTRON_SKIP_BINARY_DOWNLOAD=1
    pnpm rebuild --pending "''${pnpmInstallFlags[@]}" \
      --filter '!@t3tools/monorepo'
  '';

  pnpmBuildScript = "build:desktop";

  # Dependencies include prebuilt artifacts for foreign systems and statically
  # linked executables, which must not be patched or audited as host binaries.
  dontPatchELF = true;
  noAuditTmpdir = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/libexec/t3code/apps/server"
    cp -r --no-preserve=mode node_modules "$out/libexec/t3code/"
    cp -r --no-preserve=mode apps/server/{node_modules,dist} "$out/libexec/t3code/apps/server/"

    mkdir -p "$out/libexec/t3code/apps/server/dist/resource-monitor/${platformKey}"
    install -Dm755 ${resourceMonitor}/bin/t3-resource-monitor \
      "$out/libexec/t3code/apps/server/dist/resource-monitor/${platformKey}/t3-resource-monitor"

    mkdir -p "$out/bin"
    makeWrapper ${lib.getExe nodejs_24} "$out/bin/t3" \
      --add-flags "$out/libexec/t3code/apps/server/dist/bin.mjs"

    mkdir -p "$desktop/libexec/t3code/apps/desktop"
    cp -r --no-preserve=mode \
      apps/desktop/{package.json,node_modules,dist-electron} \
      "$desktop/libexec/t3code/apps/desktop/"
    mkdir -p "$desktop/libexec/t3code/apps/desktop/prod-resources"
    install -Dm444 ${desktopIcon} \
      "$desktop/libexec/t3code/apps/desktop/prod-resources/icon.png"

    ln -s "$out/libexec/t3code/node_modules" "$desktop/libexec/t3code/node_modules"
    ln -s "$out/libexec/t3code/apps/server" "$desktop/libexec/t3code/apps/server"

    mkdir -p "$desktop/libexec/t3code/apps/desktop/prod-resources/resource-monitor"
    ln -s \
      "$out/libexec/t3code/apps/server/dist/resource-monitor/${platformKey}/t3-resource-monitor" \
      "$desktop/libexec/t3code/apps/desktop/prod-resources/resource-monitor/t3-resource-monitor"

    find "$out/libexec/t3code" "$desktop/libexec/t3code" -xtype l -delete

    mkdir -p "$desktop/bin"
    makeWrapper ${lib.getExe electron_43} "$desktop/bin/t3code-desktop" \
      --add-flags "$desktop/libexec/t3code/apps/desktop" \
      --inherit-argv0

    mkdir -p "$desktop/share/icons/hicolor/scalable/apps"
    install -Dm444 ${desktopIcon} "$desktop/share/icons/t3code.png"
    install -Dm444 assets/prod/logo.svg "$desktop/share/icons/hicolor/scalable/apps/t3code.svg"
    cp -r ${desktopItem}/share/applications "$desktop/share/"

    ${lib.optionalString stdenv.hostPlatform.isDarwin ''
      find "$desktop/libexec/t3code" \
        -path '*/node-pty/prebuilds/darwin-*/spawn-helper' \
        -exec chmod 755 {} +

      mkdir -p "$desktop/Applications/${appName}.app/Contents/"{MacOS,Resources}
      png2icns \
        "$desktop/Applications/${appName}.app/Contents/Resources/t3code.icns" \
        ${desktopIcon}
      ${stdenv.shell} ${lib.getExe writeDarwinBundle} \
        "$desktop" "${appName}" t3code-desktop t3code
    ''}

    runHook postInstall
  '';

  postInstall = ''
    for shell in bash fish zsh; do
      installShellCompletion --cmd t3 --"$shell" <("$out/bin/t3" --completions "$shell")
    done
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];
  versionCheckProgramArg = [ "--version" ];

  passthru = {
    category = "AI Coding Agents";
    inherit appName resourceMonitor;
  };

  meta = {
    description = "Control surface for coding agents";
    homepage = "https://t3.codes";
    changelog = "https://github.com/pingdotgg/t3code/releases/tag/v${version}";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ dancodes ];
    mainProgram = "t3";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "aarch64-darwin"
    ];
  };
}
