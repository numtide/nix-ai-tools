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
  pname = "goose-server";
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

  buildInputs = [ openssl ];

  env.RUSTY_V8_ARCHIVE = fetchurl {
    name = "librusty_v8-${librusty_v8.version}";
    url = "https://github.com/denoland/rusty_v8/releases/download/v${librusty_v8.version}/librusty_v8_release_${stdenv.hostPlatform.rust.rustcTarget}.a.gz";
    hash = librusty_v8.hashes.${stdenv.hostPlatform.system};
    meta.sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };

  # Upstream enables local inference by default, which pulls in llama.cpp.
  # Package the server without that optional feature to keep the build tractable.
  cargoBuildFlags = [
    "--no-default-features"
    "--features"
    "code-mode"
    "--package"
    "goose-server"
  ];

  doCheck = false;

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  passthru.category = "AI Coding Agents";

  meta = with lib; {
    description = "HTTP server for Goose - a local, extensible, open source AI agent";
    homepage = "https://github.com/block/goose";
    changelog = "https://github.com/block/goose/releases/tag/v${version}";
    license = licenses.asl20;
    sourceProvenance = with sourceTypes; [
      fromSource
      binaryNativeCode
    ];
    mainProgram = "goosed";
  };
}
