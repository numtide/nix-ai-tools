{
  lib,
  stdenv,
  fetchFromGitHub,
  bun2nix,
  bun,
  makeWrapper,
  sqlite,
  autoPatchelfHook,
  flake,

  # GPU support
  config,
  cudaSupport,
  cudaPackages ? { },
  vulkanSupport ? stdenv.isLinux,
  vulkan-loader,
  autoAddDriverRunpath,
}:
let
  # CUDA only supported on x86_64-linux
  effectiveCudaSupport = cudaSupport && stdenv.isLinux && stdenv.hostPlatform.isx86_64;
  # Vulkan supported on all Linux
  effectiveVulkanSupport = vulkanSupport && stdenv.isLinux;

  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version hash;
in
stdenv.mkDerivation {
  pname = "qmd";
  inherit version;

  src = fetchFromGitHub {
    owner = "tobi";
    repo = "qmd";
    tag = "v${version}";
    inherit hash;
  };

  nativeBuildInputs = [
    bun2nix.hook
    makeWrapper
  ]
  ++ lib.optionals stdenv.isLinux [ autoPatchelfHook ]
  ++ lib.optionals effectiveCudaSupport [ autoAddDriverRunpath ];

  buildInputs = [
    sqlite
  ]
  ++ lib.optionals stdenv.isLinux [
    stdenv.cc.cc.lib # For libgcc_s.so.1 and libstdc++.so.6
  ]
  ++ lib.optionals effectiveCudaSupport [
    cudaPackages.cuda_cudart
    cudaPackages.libcublas
  ]
  ++ lib.optionals effectiveVulkanSupport [
    vulkan-loader
  ];

  bunDeps = bun2nix.fetchBunDeps {
    bunNix = ./bun.nix;
  };

  # Ignore missing optional dependencies based on enabled GPU backends
  autoPatchelfIgnoreMissingDeps = [
    # musl (we use glibc)
    "libc.musl-x86_64.so.1"
    "libc.musl-aarch64.so.1"
    # Prebuilt binaries target CUDA 13 but we provide CUDA 12 (ABI compatible)
    # libcuda.so.1 comes from nvidia driver (autoAddDriverRunpath)
    "libcudart.so.13"
    "libcublas.so.13"
    "libcuda.so.1"
  ]
  # CUDA 12 libs — only ignore when CUDA is disabled (otherwise provided by cudaPackages)
  ++ lib.optionals (!effectiveCudaSupport) [
    "libcudart.so.12"
    "libcublas.so.12"
  ]
  ++ lib.optionals (!effectiveVulkanSupport) [
    "libvulkan.so.1"
  ];

  # No build step needed - we'll run directly with bun
  dontUseBunBuild = true;
  dontUseBunInstall = true;

  installPhase =
    let
      # Build LD_LIBRARY_PATH with all required libraries
      ldLibraryPath =
        lib.makeLibraryPath (
          [ sqlite.out ]
          ++ lib.optionals effectiveCudaSupport [
            cudaPackages.cuda_cudart
            cudaPackages.libcublas
          ]
          ++ lib.optionals effectiveVulkanSupport [
            vulkan-loader
          ]
        )
        # Add NixOS driver path for libcuda.so.1 (loaded via dlopen at runtime)
        + lib.optionalString effectiveCudaSupport ":/run/opengl-driver/lib";
    in
    ''
      runHook preInstall

      mkdir -p $out/lib/qmd $out/bin

      cp -r node_modules src package.json $out/lib/qmd/

      # Patch detectGlibc.js to always return true on Linux
      # node-llama-cpp checks FHS paths (/lib, /usr/lib) for glibc which don't exist on NixOS
      # Without this patch, it falls back to building llama.cpp which fails in read-only store
      patch -p1 -d $out/lib/qmd < ${./node-llama-cpp-detectGlibc.patch}

      # Redirect writable paths (localBuilds, llama.cpp clone, toolchains, xpack,
      # build metadata) from the read-only Nix store to ~/.cache/node-llama-cpp.
      # When the prebuilt CUDA binary fails its compatibility test, node-llama-cpp
      # falls back to building llama.cpp from source, which requires cloning the
      # repo and writing build artifacts. On NixOS these paths resolve to
      # /nix/store/... which is read-only, causing EROFS errors.
      # Read-only assets (prebuilt bins, grammars, git bundle, release JSON) are
      # kept pointing to the Nix store.
      patch -p1 -d $out/lib/qmd < ${./node-llama-cpp-nix-compat.patch}

      makeWrapper ${bun}/bin/bun $out/bin/qmd \
        --add-flags "$out/lib/qmd/src/qmd.ts" \
        --set DYLD_LIBRARY_PATH "${sqlite.out}/lib" \
        --set LD_LIBRARY_PATH "${ldLibraryPath}"

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
    sourceProvenance = with lib.sourceTypes; [
      fromSource
      binaryNativeCode
    ];
    maintainers = with flake.lib.maintainers; [ mulatta ];
    platforms = lib.platforms.unix;
    mainProgram = "qmd";
  };
}
