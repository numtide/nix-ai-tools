{
  runCommand,
  clang-tools,
  sourceFiles,
}:

runCommand "wrap-buddy-clang-tidy"
  {
    nativeBuildInputs = [ clang-tools ];
    src = sourceFiles;
  }
  ''
    cd $src
    # Run clang-tidy on C source files
    # -DLOADER_PATH required by stub.c
    clang-tidy loader.c stub.c -- \
      -DLOADER_PATH='"/nix/store/dummy/loader.bin"' \
      -I.
    touch $out
  ''
