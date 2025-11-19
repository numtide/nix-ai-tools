{
  lib,
  stdenv,
  fetchurl,
  undmg,
  autoPatchelfHook,
  gcc,
}:

let
  version = "1.11.3-6583016683339776";

  sources = {
    x86_64-linux = {
      url = "https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/${version}/linux-x64/Antigravity.tar.gz";
      hash = "sha256-Al2lEvl5mnFU4sx1vAkIIBOCwazy6DePnaI1y4SlYVs=";
    };
    x86_64-darwin = {
      url = "https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/${version}/darwin-x64/Antigravity.dmg";
      hash = lib.fakeHash;
    };
    aarch64-darwin = {
      url = "https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/${version}/darwin-arm/Antigravity.dmg";
      hash = lib.fakeHash;
    };
  };

  source =
    sources.${stdenv.hostPlatform.system}
      or (throw "Unsupported system: ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation rec {
  pname = "antigravity";
  inherit version;

  src = fetchurl source;

  nativeBuildInputs =
    lib.optionals stdenv.hostPlatform.isDarwin [
      undmg
    ]
    ++ lib.optionals stdenv.hostPlatform.isLinux [
      autoPatchelfHook
    ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    gcc.cc.lib
  ];

  sourceRoot = ".";

  installPhase =
    if stdenv.hostPlatform.isDarwin then
      ''
        runHook preInstall

        mkdir -p $out/Applications
        cp -r Antigravity.app $out/Applications/

        runHook postInstall
      ''
    else
      ''
        runHook preInstall

        mkdir -p $out/bin
        cp -r Antigravity/bin/antigravity $out/bin/
        chmod +x $out/bin/antigravity

        runHook postInstall
      '';

  meta = with lib; {
    description = "Antigravity application";
    homepage = "https://antigravity.google";
    license = licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    maintainers = with maintainers; [ ];
    platforms = [
      "x86_64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    mainProgram = "antigravity";
  };
}
