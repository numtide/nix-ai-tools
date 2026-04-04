{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchurl,
  rustPlatform,
  pkg-config,
  openssl,
  libclang,
  clang,
  cmake,
  libxcb,
  dbus,
  versionCheckHook,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData)
    version
    hash
    cargoHash
    librusty_v8
    ;
in
rustPlatform.buildRustPackage rec {
  pname = "goose-cli";
  inherit version cargoHash;

  src = fetchFromGitHub {
    owner = "block";
    repo = "goose";
    rev = "v${version}";
    inherit hash;
  };

  LIBCLANG_PATH = "${libclang.lib}/lib";

  nativeBuildInputs = [
    pkg-config
    libclang
    clang
    cmake
  ];

  buildInputs = [
    openssl
    libxcb
    dbus
  ];

  env.RUSTY_V8_ARCHIVE = fetchurl {
    name = "librusty_v8-${librusty_v8.version}";
    url = "https://github.com/denoland/rusty_v8/releases/download/v${librusty_v8.version}/librusty_v8_release_${stdenv.hostPlatform.rust.rustcTarget}.a.gz";
    hash = librusty_v8.hashes.${stdenv.hostPlatform.system};
    meta.sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };

  # Upstream enables local inference by default, which pulls in llama.cpp.
  # Package the CLI without that optional feature to keep the build tractable.
  # Also disable the built-in self-update command because Nix manages updates.
  cargoBuildFlags = [
    "--no-default-features"
    "--features"
    "code-mode,disable-update"
    "--package"
    "goose-cli"
  ];

  doCheck = false;

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  passthru.category = "AI Coding Agents";

  meta = with lib; {
    description = "CLI for Goose - a local, extensible, open source AI agent that automates engineering tasks";
    homepage = "https://github.com/block/goose";
    changelog = "https://github.com/block/goose/releases/tag/v${version}";
    license = licenses.asl20;
    sourceProvenance = with sourceTypes; [
      fromSource
      binaryNativeCode
    ];
    mainProgram = "goose";
  };
}
