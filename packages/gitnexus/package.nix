{
  flake,
  lib,
  stdenv,
  buildNpmPackage,
  fetchFromGitHub,
  fetchNpmDepsWithPackuments,
  npmConfigHook,
  makeWrapper,
}:

buildNpmPackage (finalAttrs: {
  inherit npmConfigHook;
  pname = "gitnexus";
  version = "1.4.10";

  src = fetchFromGitHub {
    owner = "abhigyanpatwari";
    repo = "GitNexus";
    rev = "c27c9f612ca606252f3627cb364c5efa6fbd6f83";
    hash = "sha256-ywTPFUt7kmaUbEz+mL+LS4m3ykZ6vZLKyV/iJ2GNcKU=";
  };

  sourceRoot = "source/gitnexus";

  patches = [ ./system-onnxruntime-node.patch ];

  npmDeps = fetchNpmDepsWithPackuments {
    inherit (finalAttrs) src;
    sourceRoot = "source/gitnexus";
    name = "${finalAttrs.pname}-${finalAttrs.version}-npm-deps";
    hash = "sha256-uEONNB0BIb6AEiXJjAC3/xzSt3XMQB8CpyLzZIxBCeM=";
    fetcherVersion = 2;
    forceGitDeps = true;
  };
  makeCacheWritable = true;

  npmFlags = [ "--ignore-scripts" ];

  nativeBuildInputs = [ makeWrapper ];

  postInstall =
    let
      ortPlatform =
        if stdenv.hostPlatform.isDarwin then
          "darwin"
        else if stdenv.hostPlatform.isLinux then
          "linux"
        else
          throw "Unsupported platform for gitnexus: ${stdenv.hostPlatform.system}";
      ortArch =
        if stdenv.hostPlatform.isAarch64 then
          "arm64"
        else if stdenv.hostPlatform.isx86_64 then
          "x64"
        else
          throw "Unsupported CPU for gitnexus: ${stdenv.hostPlatform.parsed.cpu.name}";
      ortBinding = "$out/lib/node_modules/gitnexus/node_modules/onnxruntime-node/bin/napi-v6/${ortPlatform}/${ortArch}/onnxruntime_binding.node";
    in
    ''
      wrapProgram $out/bin/gitnexus \
        --set-default GITNEXUS_ORT_BINDING_PATH "${ortBinding}"
    '';

  passthru.category = "AI Coding Agents";

  meta = with lib; {
    description = "Graph-powered code intelligence for AI agents";
    homepage = "https://github.com/abhigyanpatwari/GitNexus";
    changelog = "https://github.com/abhigyanpatwari/GitNexus/releases";
    license = licenses.unfree;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ ];
    mainProgram = "gitnexus";
    platforms = platforms.linux ++ platforms.darwin;
  };
})
