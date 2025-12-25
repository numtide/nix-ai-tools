{
  runCommand,
  clang-tools,
  sourceFiles,
}:

runCommand "wrap-buddy-clang-format"
  {
    nativeBuildInputs = [ clang-tools ];
    src = sourceFiles;
  }
  ''
    cd $src
    # Check C source files are properly formatted
    clang-format --dry-run loader.c stub.c
    touch $out
  ''
