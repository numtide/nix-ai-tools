{
  lib,
  flake,
  stdenv,
  rustPlatform,
  fetchFromGitHub,
  runCommand,
  nodejs,
  fetchNpmDepsWithPackuments,
  npmConfigHook,
  versionCheckHook,
  versionCheckHomeHook,
}:
let
  pname = "zeroclaw";
  version = "0.6.8";

  src = fetchFromGitHub {
    owner = "zeroclaw-labs";
    repo = "zeroclaw";
    tag = "v${version}";
    hash = "sha256-SdIfROs3fwiB/7laMwlcV8xBlxMMWRseMKw9Gg620ik=";
  };

  frontendSrc = runCommand "${pname}-web-src-${version}" { } ''
    mkdir -p $out
    cp -r ${src}/web/. $out/
  '';

  frontend = stdenv.mkDerivation {
    pname = "${pname}-frontend";
    inherit version;
    src = frontendSrc;

    nativeBuildInputs = [
      nodejs
      npmConfigHook
    ];

    npmDeps = fetchNpmDepsWithPackuments {
      src = frontendSrc;
      name = "${pname}-${version}-npm-deps";
      hash = "sha256-LAHTNJX9Fgml2H8T7pE7uhXiDZ8hWtczOryN5SaEqw8=";
      fetcherVersion = 2;
    };
    makeCacheWritable = true;

    buildPhase = ''
      runHook preBuild
      npm run build
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r dist/* $out/
      runHook postInstall
    '';
  };
in
rustPlatform.buildRustPackage rec {
  inherit pname version src;

  cargoHash = "sha256-/Uu+AlhFgmCymYPTs6K4Ffd0TfILCiymYkVgL9tZ1zU=";

  preBuild = ''
    mkdir -p web/dist
    cp -r ${frontend}/* web/dist/
  '';

  # Tests require runtime configuration and network access
  doCheck = false;

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];

  passthru = {
    inherit frontend;
    category = "AI Assistants";
  };

  meta = {
    description = "Fast, small, and fully autonomous AI assistant infrastructure";
    homepage = "https://github.com/zeroclaw-labs/zeroclaw";
    changelog = "https://github.com/zeroclaw-labs/zeroclaw/releases/tag/v${version}";
    license = with lib.licenses; [
      mit
      asl20
    ];
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ commandodev ];
    mainProgram = "zeroclaw";
    platforms = lib.platforms.unix;
  };
}
