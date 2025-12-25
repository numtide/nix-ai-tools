{
  lib,
  stdenv,
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

  # Header files for C compilation
  headers = [
    ./arch.h
    ./config.h
    ./debug.h
    ./elf_defs.h
    ./elf_types.h
    ./freestanding.h
    ./mmap.h
    ./preamble.ld
    ./arch
  ];

  # Source files for stub compilation (used by wrap-buddy.py at runtime)
  cSources = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions (headers ++ [ ./stub.c ]);
  };

  # Source files for loader builds
  loaderSources = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions (headers ++ [ ./loader.c ]);
  };

  # Function to build loader for a specific architecture
  # Since the loader is freestanding (-nostdlib), we can cross-compile
  # using just compiler flags instead of a full cross toolchain
  mkLoaderBin =
    {
      suffix,
      archFlags ? "",
    }:
    stdenv.mkDerivation {
      pname = "wrap-buddy-loader-${suffix}";
      version = "0.3.0";

      src = loaderSources;

      nativeBuildInputs = [ binutils ];

      buildPhase = ''
        runHook preBuild

        # Compile loader to ELF, then extract flat binary with objcopy
        # Use -Ttext=0 to ensure code starts at address 0
        # Use -nostdinc to avoid pulling in system headers (enables -m32 cross-compile)
        $CC -nostdlib -nostdinc -fPIC -fno-stack-protector \
          -fno-exceptions -fno-unwind-tables \
          -fno-asynchronous-unwind-tables -fno-builtin \
          -Os -I. ${archFlags} \
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
        platforms = [
          "x86_64-linux"
          "i686-linux"
          "aarch64-linux"
        ];
      };
    };

  # Native loader (64-bit on x86_64, 64-bit on aarch64)
  # For aarch64: use -mcmodel=tiny to get truly PC-relative addressing (adr not adrp)
  loaderBin = mkLoaderBin {
    suffix = "native";
    archFlags = lib.optionalString stdenv.hostPlatform.isAarch64 "-mcmodel=tiny";
  };

  # 32-bit loader (only on x86_64-linux, using -m32)
  loaderBin32 =
    if stdenv.hostPlatform.isx86_64 then
      mkLoaderBin {
        suffix = "i686";
        archFlags = "-m32";
      }
    else
      null;

  wrapBuddyScript = stdenv.mkDerivation {
    pname = "wrap-buddy";
    version = "0.3.0";

    src = lib.fileset.toSource {
      root = ./.;
      fileset = lib.fileset.unions (
        headers
        ++ [
          ./wrap-buddy.py
          ./stub.c
        ]
      );
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

  # Source files for clang-tidy/clang-format
  sourceFiles = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions (
      headers
      ++ [
        ./loader.c
        ./stub.c
        ./.clang-tidy
      ]
    );
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
