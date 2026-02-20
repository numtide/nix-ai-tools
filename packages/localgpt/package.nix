{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  openssl,
  onnxruntime,
  libGL,
  libxkbcommon,
  wayland,
  libx11,
  libxcursor,
  libxi,
  libxrandr,
  versionCheckHook,
  versionCheckHomeHook,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version hash cargoHash;
in
rustPlatform.buildRustPackage {
  pname = "localgpt";
  inherit version;

  src = fetchFromGitHub {
    owner = "localgpt-app";
    repo = "localgpt";
    tag = "v${version}";
    inherit hash;
  };

  cargoPatches = [ ./update-lockfile.patch ];

  inherit cargoHash;

  # Disable slow LTO and single codegen-unit for faster Nix builds.
  # Enable x11 and wayland features for eframe (upstream disables defaults).
  postPatch = ''
    substituteInPlace Cargo.toml \
      --replace-fail 'lto = true' 'lto = false' \
      --replace-fail 'codegen-units = 1' "" \
      --replace-fail 'default-features = false, features = [' 'default-features = false, features = ["x11", "wayland",'
  '';

  nativeBuildInputs = [ pkg-config ];

  buildInputs = [
    openssl
    onnxruntime
    # eframe/glow compile-time deps
    libGL
    libxkbcommon
    wayland
    libx11
    libxcursor
    libxi
    libxrandr
  ];

  env = {
    # Use system onnxruntime instead of downloading binaries
    ORT_LIB_LOCATION = "${lib.getLib onnxruntime}/lib";
    ORT_PREFER_DYNAMIC_LINK = "1";
  };

  # Add runtime library paths for dlopen'd libs (onnxruntime, GL, wayland, xkbcommon)
  postFixup = ''
    patchelf --add-rpath "${
      lib.makeLibraryPath [
        onnxruntime
        libGL
        libxkbcommon
        wayland
      ]
    }" $out/bin/localgpt
  '';

  # Tests require network access and writable directories
  doCheck = false;

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];

  passthru.category = "AI Assistants";

  meta = with lib; {
    description = "Local AI assistant with persistent markdown memory, autonomous tasks, and semantic search";
    homepage = "https://github.com/localgpt-app/localgpt";
    license = licenses.asl20;
    sourceProvenance = with sourceTypes; [ fromSource ];
    # onnxruntime rpath linking is broken on Darwin
    platforms = platforms.linux;
    mainProgram = "localgpt";
  };
}
