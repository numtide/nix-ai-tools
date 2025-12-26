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
    # Check C and C++ source files are properly formatted
    if ! find src -name '*.c' -o -name '*.cc' -o -name '*.h' | xargs -P"$NIX_BUILD_CORES" -n1 clang-format --dry-run --Werror; then
      echo ""
      echo "ERROR: Source files are not properly formatted."
      echo "Run 'make format' to fix formatting issues."
      exit 1
    fi
    touch $out
  ''
