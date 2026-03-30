{
  flake,
  lib,
  stdenv,
  buildNpmPackage,
  fetchFromGitHub,
  fetchNpmDepsWithPackuments,
  npmConfigHook,
  makeWrapper,
  nodePackages,
}:

buildNpmPackage (finalAttrs: {
  inherit npmConfigHook;
  pname = "gitnexus";
  version = "1.4.10";

  src = fetchFromGitHub {
    owner = "PieterPel";
    repo = "GitNexus";
    rev = "fefa95354effa7a29e9b3b65735d3fbb56fd5933";
    hash = "sha256-YfI6m/rfswGwwN68AlTyFBosGhniasq4uc3Xh6e5gXc=";
  };

  sourceRoot = "source/gitnexus";

  patches = [ ];

  postUnpack = ''
    chmod -R u+w source/gitnexus-shared
  '';

  npmDeps = fetchNpmDepsWithPackuments {
    inherit (finalAttrs) src;
    sourceRoot = "source/gitnexus";
    name = "${finalAttrs.pname}-${finalAttrs.version}-npm-deps";
    hash = "sha256-DIrte2Ksc3zzSZx9jQ58j5rq9D+qcygsJ8/1m7XmheQ=";
    fetcherVersion = 2;
    forceGitDeps = true;
  };
  makeCacheWritable = true;

  npmFlags = [ "--ignore-scripts" ];

  nativeBuildInputs = [
    makeWrapper
    nodePackages.typescript
  ];

  preBuild = ''
    pushd ../gitnexus-shared
    tsc
    popd
  '';

  dontPatchELF = stdenv.hostPlatform.isDarwin;

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
      mkdir -p $out/lib/node_modules/gitnexus-shared
      cp -R ../gitnexus-shared/dist ../gitnexus-shared/src ../gitnexus-shared/package.json \
        $out/lib/node_modules/gitnexus-shared/

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
