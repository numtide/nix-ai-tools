{
  flake,
  lib,
  stdenv,
  buildNpmPackage,
  fetchFromGitHub,
  fetchNpmDepsWithPackuments,
  npmConfigHook,
  makeWrapper,
  typescript,
}:

buildNpmPackage (finalAttrs: {
  inherit npmConfigHook;
  pname = "gitnexus";
  version = "1.6.1";

  src = fetchFromGitHub {
    owner = "abhigyanpatwari";
    repo = "GitNexus";
    rev = "c72890d59d41f928c91f4d7b5c94fc2981f80ebe";
    hash = "sha256-p0l2dDD788opW3ocSphVQ1Yd9eXHox/TwNTh6aSPdwU=";
  };

  sourceRoot = "source/gitnexus";

  # Upstream: https://github.com/abhigyanpatwari/GitNexus/pull/589
  patches = [ ./system-onnxruntime-node.patch ];

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
    typescript
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
      lbugBindingSource = "$out/lib/node_modules/gitnexus/node_modules/@ladybugdb/core-${ortPlatform}-${ortArch}/lbugjs.node";
      lbugBindingTarget = "$out/lib/node_modules/gitnexus/node_modules/@ladybugdb/core/lbugjs.node";
    in
    ''
      mkdir -p $out/lib/node_modules/gitnexus-shared
      cp -R ../gitnexus-shared/dist ../gitnexus-shared/src ../gitnexus-shared/package.json \
        $out/lib/node_modules/gitnexus-shared/

      if [ -f "${lbugBindingSource}" ]; then
        cp "${lbugBindingSource}" "${lbugBindingTarget}"
      else
        echo "Expected LadybugDB native module at ${lbugBindingSource} but it was not found." >&2
        exit 1
      fi

      wrapProgram $out/bin/gitnexus \
        --set-default GITNEXUS_ORT_BINDING_PATH "${ortBinding}" \
        --run 'export GITNEXUS_CACHE_DIR="$HOME/.cache"'
    '';

  passthru.category = "AI Coding Agents";

  meta = with lib; {
    description = "Graph-powered code intelligence for AI agents";
    homepage = "https://github.com/abhigyanpatwari/GitNexus";
    changelog = "https://github.com/abhigyanpatwari/GitNexus/releases";
    license = licenses.unfree;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ PieterPel ];
    mainProgram = "gitnexus";
    platforms = platforms.linux ++ platforms.darwin;
  };
})
