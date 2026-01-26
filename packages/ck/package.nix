{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  openssl,
  onnxruntime,
  stdenv,
  darwinMinVersionHook,
}:
rustPlatform.buildRustPackage {
  pname = "ck";
  version = "0.7.4";

  src = fetchFromGitHub {
    owner = "BeaconBay";
    repo = "ck";
    tag = "0.7.4";
    hash = "sha256-fUD/YeOMy8+oM1UA4clqto0i3gSZkyRuhxBnNb0KYTI=";
  };

  cargoHash = "sha256-ULuvrXV7+RsaHouuE2MuOWvR0KERkovGY8TVBeDIkjg=";

  nativeBuildInputs = [ pkg-config ];

  buildInputs = [
    openssl
    onnxruntime
  ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [
    (darwinMinVersionHook "11.0")
  ];

  cargoBuildFlags = [ "--package=ck-search" ];

  # Tests require onnxruntime at runtime via @rpath
  doCheck = false;

  env = {
    # Use system onnxruntime instead of downloading binaries
    ORT_LIB_LOCATION = "${lib.getLib onnxruntime}/lib";
    ORT_PREFER_DYNAMIC_LINK = "1";
  };

  postFixup = lib.optionalString stdenv.hostPlatform.isDarwin ''
    install_name_tool -add_rpath "${lib.getLib onnxruntime}/lib" $out/bin/ck
  '';

  passthru.category = "AI Coding Agents";

  meta = with lib; {
    description = "Local first semantic and hybrid BM25 grep / search tool for use by AI and humans!";
    homepage = "https://github.com/BeaconBay/ck";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [ fromSource ];
    mainProgram = "ck";
  };
}
