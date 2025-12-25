{
  lib,
  stdenv,
  llvmPackages_latest,
  binutils,
  xxd,
  sourceFiles,
}:

let
  libcxx = llvmPackages_latest.libcxx;
in
stdenv.mkDerivation {
  name = "wrap-buddy-clang-tidy";
  src = sourceFiles;

  nativeBuildInputs = [
    llvmPackages_latest.clang-tools
    binutils
    xxd
  ];

  buildPhase = ''
    make clang-tidy \
      EXTRA_CXXFLAGS="-stdlib=libc++ -isystem ${libcxx.dev}/include/c++/v1" \
      INTERP=/nix/store/dummy/ld.so \
      LIBC_LIB=/nix/store/dummy/lib
  '';

  installPhase = "touch $out";

  meta.platforms = lib.platforms.linux;
}
