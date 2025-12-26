{
  lib,
  stdenv,
  buildPackages,
  callPackage,
  makeSetupHook,
  writeText,
  binutils,
  xxd,
  strace,
  pkgsi686Linux,
}:

let
  # Source files for building everything
  sources = lib.fileset.toSource {
    root = ./..;
    fileset = lib.fileset.unions [
      ./../include/wrap-buddy
      ./../Makefile
      ./../src
      ./../.clang-tidy
      ./../tests
    ];
  };

  # Read interpreter info from bintools at build time
  dynamicLinker = lib.strings.trim (
    builtins.readFile "${stdenv.cc.bintools}/nix-support/dynamic-linker"
  );

  origLibc = "${stdenv.cc.bintools}/nix-support/orig-libc";

  libcLib =
    if builtins.pathExists origLibc then
      "${lib.strings.trim (builtins.readFile origLibc)}/lib"
    else
      null;

  # Cross-compilation support:
  # - CC (from stdenv) builds stubs for TARGET platform (what gets patched)
  # - CXX_FOR_BUILD builds wrap-buddy for BUILD platform (what runs the patcher)
  # For native builds, these are the same compiler.
  cxxForBuild = "${buildPackages.stdenv.cc}/bin/c++";

  # Single derivation builds everything:
  # - loader.bin, stub.bin (and 32-bit variants on x86_64)
  # - wrap-buddy C++ patcher with embedded stubs
  wrapBuddy = stdenv.mkDerivation {
    pname = "wrap-buddy";
    version = "0.4.0";

    src = sources;

    # depsBuildBuild: tools that run on BUILD and compile for BUILD
    depsBuildBuild = [
      buildPackages.stdenv.cc # C++ compiler for wrap-buddy
    ];

    nativeBuildInputs = [
      binutils # objcopy (processes target ELF files)
      xxd # for embedding stubs (platform-independent)
    ];

    makeFlags = [
      "CXX_FOR_BUILD=${cxxForBuild}"
      "BINDIR=$(out)/bin"
      "LIBDIR=$(out)/lib/wrap-buddy"
      "INTERP=${dynamicLinker}"
    ]
    ++ lib.optional (libcLib != null) "LIBC_LIB=${libcLib}"
    ++ lib.optional stdenv.hostPlatform.isx86_64 "BUILD_32BIT=1";

    nativeInstallCheckInputs = [ strace ];
    doInstallCheck = true;
    installCheckTarget = "check";
    enableParallelBuilding = true;

    meta = {
      description = "Patch ELF binaries with stub loader for NixOS compatibility";
      mainProgram = "wrap-buddy";
      license = lib.licenses.mit;
      platforms = [
        "x86_64-linux"
        "i686-linux"
        "aarch64-linux"
      ];
    };
  };

  hookScript = writeText "wrap-buddy-hook.sh" (builtins.readFile ./wrap-buddy-hook.sh);

  hook = makeSetupHook {
    name = "wrap-buddy-hook";
    propagatedBuildInputs = [ wrapBuddy ];
    meta = {
      description = "Setup hook that patches ELF binaries with stub loader";
      license = lib.licenses.mit;
      platforms = lib.platforms.linux;
    };
    passthru.tests = {
      clang-tidy = callPackage ./clang-tidy.nix { sourceFiles = sources; };
      clang-format = callPackage ./clang-format.nix { sourceFiles = sources; };
    }
    // lib.optionalAttrs stdenv.hostPlatform.isx86_64 {
      # Test 32-bit patching by building wrapBuddy with i686 stdenv
      test-32bit = pkgsi686Linux.callPackage ./package.nix { };
    };
  } hookScript;
in
hook
