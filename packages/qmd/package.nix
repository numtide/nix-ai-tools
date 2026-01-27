{
  lib,
  stdenv,
  buildNpmPackage,
  fetchFromGitHub,
  bun,
  makeWrapper,
  sqlite,
  fetchNpmDepsWithPackuments,
  npmConfigHook,
  jq,
  autoPatchelfHook,
}:
let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) rev srcHash npmDepsHash;

  version = "1.0.0-unstable";

  src = fetchFromGitHub {
    owner = "tobi";
    repo = "qmd";
    inherit rev;
    hash = srcHash;
  };

  # Shared patch: add package-lock.json and remove win32 optional dependency
  postPatch = ''
    cp ${./package-lock.json} package-lock.json
    # Remove win32 optional dependency from package.json to match our package-lock.json
    ${jq}/bin/jq 'del(.optionalDependencies."sqlite-vec-win32-x64")' package.json > package.json.tmp
    mv package.json.tmp package.json
  '';
in
buildNpmPackage {
  inherit
    npmConfigHook
    version
    src
    postPatch
    ;
  pname = "qmd";

  npmDeps = fetchNpmDepsWithPackuments {
    inherit src postPatch;
    name = "qmd-${version}-npm-deps";
    hash = npmDepsHash;
    fetcherVersion = 2;
  };
  makeCacheWritable = true;

  nativeBuildInputs = [
    makeWrapper
  ]
  ++ lib.optionals stdenv.isLinux [ autoPatchelfHook ];

  buildInputs = [
    sqlite
  ]
  ++ lib.optionals stdenv.isLinux [
    stdenv.cc.cc.lib # For libgcc_s.so.1 and libstdc++.so.6
  ];

  # Ignore missing optional dependencies for CUDA, Vulkan, and musl
  autoPatchelfIgnoreMissingDeps = [
    "libcudart.so.13"
    "libcublas.so.13"
    "libcuda.so.1"
    "libcudart.so.12"
    "libcublas.so.12"
    "libvulkan.so.1"
    "libc.musl-x86_64.so.1"
    "libc.musl-aarch64.so.1"
  ];

  # Skip any build scripts since this is a TypeScript project run with bun
  npmFlags = [ "--ignore-scripts" ];

  # No build step needed - we'll run directly with bun
  dontNpmBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/qmd $out/bin

    cp -r node_modules src package.json $out/lib/qmd/

    # Patch detectGlibc.js to always return true on Linux
    # node-llama-cpp checks FHS paths (/lib, /usr/lib) for glibc which don't exist on NixOS
    # Without this patch, it falls back to building llama.cpp which fails in read-only store
    patch -p1 -d $out/lib/qmd < ${./node-llama-cpp-detectGlibc.patch}

    makeWrapper ${bun}/bin/bun $out/bin/qmd \
      --add-flags "$out/lib/qmd/src/qmd.ts" \
      --set DYLD_LIBRARY_PATH "${sqlite.out}/lib" \
      --set LD_LIBRARY_PATH "${sqlite.out}/lib"

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    # Test --help works
    HOME=$(mktemp -d) $out/bin/qmd --help | grep -q "Usage:"
    # Test actual database initialization (requires sqlite extension loading)
    HOME=$(mktemp -d) $out/bin/qmd status
    runHook postInstallCheck
  '';

  passthru.category = "Utilities";

  meta = with lib; {
    description = "mini cli search engine for your docs, knowledge bases, meeting notes, whatever. Tracking current sota approaches while being all local";
    homepage = "https://github.com/tobi/qmd";
    license = licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    platforms = lib.platforms.unix;
    mainProgram = "qmd";
  };
}
