{
  lib,
  stdenv,
  callPackage,
  python3,
  makeSetupHook,
  writeText,
  binutils,
}:

let
  pythonEnv = python3.withPackages (ps: [ ps.pyelftools ]);

  # Source files for loader/stub builds and linting
  binarySources = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./include/wrap-buddy
      ./preamble.ld
      ./Makefile
      ./loader.c
      ./stub.c
      ./.clang-tidy
    ];
  };

  # Build loader and stub binaries
  # On x86_64, also builds 32-bit variants automatically
  binaries = stdenv.mkDerivation {
    pname = "wrap-buddy-binaries";
    version = "0.3.0";

    src = binarySources;

    nativeBuildInputs = [ binutils ];

    makeFlags = [ "LIBDIR=$(out)" ];

    meta = {
      description = "Loader and stub binaries for wrapBuddy";
      license = lib.licenses.mit;
      platforms = [
        "x86_64-linux"
        "i686-linux"
        "aarch64-linux"
      ];
    };
  };

  wrapBuddyScript = stdenv.mkDerivation {
    pname = "wrap-buddy";
    version = "0.3.0";

    src = lib.fileset.toSource {
      root = ./.;
      fileset = ./wrap-buddy.py;
    };

    buildInputs = [ pythonEnv ];

    # On x86_64, the Makefile builds stub32.bin; on other platforms it doesn't exist
    installPhase =
      let
        stub32Path =
          if stdenv.hostPlatform.isx86_64 then
            "${binaries}/stub32.bin"
          else
            "@stub_path_32@";
      in
      ''
        runHook preInstall

        mkdir -p $out/bin

        # Install the main script with substituted binary paths
        substitute wrap-buddy.py $out/bin/wrap-buddy \
          --replace-fail "@stub_path_64@" "${binaries}/stub.bin" \
          --replace-fail "@stub_path_32@" "${stub32Path}"
        chmod +x $out/bin/wrap-buddy

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

  hook = makeSetupHook {
    name = "wrap-buddy-hook";
    propagatedBuildInputs = [ wrapBuddyScript ];
    meta = {
      description = "Setup hook that patches ELF binaries with stub loader";
      license = lib.licenses.mit;
      platforms = lib.platforms.linux;
    };
    passthru.tests = {
      clang-tidy = callPackage ./clang-tidy.nix { sourceFiles = binarySources; };
      clang-format = callPackage ./clang-format.nix { sourceFiles = binarySources; };
      default = callPackage ./test.nix { inherit hook; };
    };
  } hookScript;
in
hook
