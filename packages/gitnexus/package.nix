{
  flake,
  lib,
  stdenv,
  buildNpmPackage,
  fetchFromGitHub,
  makeWrapper,
  typescript,
}:

buildNpmPackage (finalAttrs: {
  npmDepsFetcherVersion = 2;
  forceGitDeps = true;
  pname = "gitnexus";
  version = "1.6.3";

  src = fetchFromGitHub {
    owner = "abhigyanpatwari";
    repo = "GitNexus";
    tag = "v${finalAttrs.version}";
    hash = "sha256-Y8JBDYJPwddK5e+U8NBlKQ9211yzVmZmNVxOaMhyl/k=";
  };

  sourceRoot = "source/gitnexus";

  # Upstream: https://github.com/abhigyanpatwari/GitNexus/pull/589
  patches = [ ./system-onnxruntime-node.patch ];

  postPatch = ''
    # scripts/build.js shells out to `npx tsc`, which tries to hit the
    # registry in the sandbox. typescript is already on PATH via
    # nativeBuildInputs, so call it directly.
    substituteInPlace scripts/build.js \
      --replace-fail "'npx tsc'" "'tsc'"
  '';

  postUnpack = ''
    chmod -R u+w source/gitnexus-shared
  '';

  npmDepsHash = "sha256-JpNOQCPty8NuUu/hr7BWZyUgc3PdVDyooFRo30tbE/w=";
  makeCacheWritable = true;

  npmFlags = [ "--ignore-scripts" ];

  nativeBuildInputs = [
    makeWrapper
    typescript
  ];

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
