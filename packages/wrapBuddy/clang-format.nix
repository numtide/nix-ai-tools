{
  lib,
  runCommand,
  clang-tools,
  sourceFiles,
}:

runCommand "wrap-buddy-clang-format"
  {
    nativeBuildInputs = [ clang-tools ];
    src = sourceFiles;
    meta.platforms = lib.platforms.all;
  }
  ''
    cd $src
    # Check C source files are properly formatted
    clang-format --dry-run loader.c stub.c
    touch $out
  ''
