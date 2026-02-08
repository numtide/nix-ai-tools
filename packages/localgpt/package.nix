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
  xorg,
  versionCheckHook,
  versionCheckHomeHook,
}:

rustPlatform.buildRustPackage rec {
  pname = "localgpt";
  version = "0.1.1";

  src = fetchFromGitHub {
    owner = "localgpt-app";
    repo = "localgpt";
    tag = "v${version}";
    hash = "sha256-qn/DZQ5Frww2k29Ntb5zk8S6ZTIr6m2xQN7JogD4CL4=";
  };

  cargoPatches = [ ./update-lockfile.patch ];

  cargoHash = "sha256-bomXXvyCV6ak0CSiqi90rSzFhO/23MrY+/Hf6IOG/nQ=";

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
    xorg.libX11
    xorg.libXcursor
    xorg.libXi
    xorg.libXrandr
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

  passthru.category = "Utilities";

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
