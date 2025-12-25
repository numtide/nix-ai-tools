{
  lib,
  stdenv,
  pkgsi686Linux,
  callPackage,
  python3,
  makeSetupHook,
  writeText,
  binutils,
  clang-tools,
  runCommand,
}:

let
  pythonEnv = python3.withPackages (ps: [ ps.pyelftools ]);

  # Source files for C compilation (headers and linker script)
  cSources = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./common.h
      ./arch.h
      ./types.h
      ./preamble.ld
      ./arch
    ];
  };

  # Common source files for loader builds
  loaderSources = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./loader.c
      ./common.h
      ./arch.h
      ./types.h
      ./preamble.ld
      ./arch
    ];
  };

  # Function to build loader for a specific architecture
  mkLoaderBin =
    {
      targetStdenv,
      suffix,
    }:
    targetStdenv.mkDerivation {
      pname = "wrap-buddy-loader-${suffix}";
      version = "0.3.0";

      src = loaderSources;

      nativeBuildInputs = [ binutils ];

      buildPhase = ''
        runHook preBuild

        # Compile loader to ELF, then extract flat binary with objcopy
        # Use -Ttext=0 to ensure code starts at address 0
        # For aarch64: use -mcmodel=tiny to get truly PC-relative addressing (adr not adrp)
        arch_flags=""
        if [[ "$($CC -dumpmachine)" == aarch64* ]]; then
          arch_flags="-mcmodel=tiny"
        fi
        $CC -nostdlib -fPIC -fno-stack-protector \
          -fno-exceptions -fno-unwind-tables \
          -fno-asynchronous-unwind-tables -fno-builtin \
          -Os -I. $arch_flags \
          -Wl,-T,preamble.ld \
          -Wl,-e,_start \
          -Wl,-Ttext=0 \
          -o loader.elf loader.c
        objcopy -O binary --only-section=.all loader.elf loader.bin

        runHook postBuild
      '';

      installPhase = ''
        runHook preInstall
        mkdir -p $out
        cp loader.bin $out/loader.bin
        runHook postInstall
      '';

      meta = {
        description = "Loader binary for wrapBuddy (${suffix})";
        license = lib.licenses.mit;
        platforms = lib.platforms.linux;
      };
    };

  # Native (64-bit or host arch) loader
  loaderBin = mkLoaderBin {
    targetStdenv = stdenv;
    suffix = "native";
  };

  # 32-bit loader (only on x86_64-linux)
  loaderBin32 =
    if stdenv.hostPlatform.isx86_64 then
      mkLoaderBin {
        targetStdenv = pkgsi686Linux.stdenv;
        suffix = "i686";
      }
    else
      null;

  wrapBuddyScript = stdenv.mkDerivation {
    pname = "wrap-buddy";
    version = "0.3.0";

    src = lib.fileset.toSource {
      root = ./.;
      fileset = lib.fileset.unions [
        ./wrap-buddy.py
        ./stub.c
        ./common.h
        ./arch.h
        ./types.h
        ./preamble.ld
        ./arch
      ];
    };

    buildInputs = [ pythonEnv ];

    installPhase =
      let
        loader32Path = if loaderBin32 != null then "${loaderBin32}/loader.bin" else "@loader_path_32@";
      in
      ''
        runHook preInstall

        mkdir -p $out/bin $out/share/wrap-buddy

        # Install the main script with substituted loader paths
        substitute wrap-buddy.py $out/bin/wrap-buddy \
          --replace-fail "@loader_path_64@" "${loaderBin}/loader.bin" \
          --replace-fail "@loader_path_32@" "${loader32Path}"
        chmod +x $out/bin/wrap-buddy

        # Install source files for stub compilation
        cp -r ${cSources}/* $out/share/wrap-buddy/
        install -Dm644 stub.c $out/share/wrap-buddy/stub.c

        runHook postInstall
      '';

    meta = {
      description = "Patch ELF binaries with stub loader for NixOS compatibility";
      mainProgram = "wrap-buddy";
      license = lib.licenses.mit;
      platforms = lib.platforms.linux;
    };
  };

  hookScript = writeText "wrap-buddy-hook.sh" (builtins.readFile ./wrap-buddy-hook.sh);

  # Source files for clang-tidy
  sourceFiles = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./loader.c
      ./stub.c
      ./common.h
      ./arch.h
      ./types.h
      ./preamble.ld
      ./arch
      ./.clang-tidy
    ];
  };

  hook = makeSetupHook {
    name = "wrap-buddy-hook";
    propagatedBuildInputs = [ wrapBuddyScript ];
    meta = {
      description = "Setup hook that patches ELF binaries with stub loader";
      license = lib.licenses.mit;
      platforms = lib.platforms.linux;
    };
    passthru.tests = {
      clang-tidy = callPackage ./clang-tidy.nix { sourceFiles = sourceFiles; };
      clang-format = callPackage ./clang-format.nix { sourceFiles = sourceFiles; };
      default = callPackage ./test.nix { inherit hook; };
    };
  } hookScript;
in
hook
