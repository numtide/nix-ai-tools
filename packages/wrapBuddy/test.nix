{
  stdenv,
  hook,
  zlib,
  libpng,
  glib,
  glibc,
  file,
  binutils,
  strace,
  pkg-config,
  patchelf,
}:

let
  # FHS-style interpreter paths for non-NixOS systems
  fhsInterpreter =
    if stdenv.hostPlatform.isx86_64 then
      "/lib64/ld-linux-x86-64.so.2"
    else if stdenv.hostPlatform.isAarch64 then
      "/lib/ld-linux-aarch64.so.1"
    else
      throw "Unsupported platform for wrapBuddy test";

  # NOP instruction for reserving space in .text section
  # x86: 0x90 (NOP), aarch64: 0x1f (part of NOP encoding d503201f)
  nopByte =
    if stdenv.hostPlatform.isx86_64 then
      "0x90"
    else if stdenv.hostPlatform.isAarch64 then
      "0x1f"
    else
      throw "Unsupported platform for wrapBuddy test";
in
stdenv.mkDerivation {
  name = "wrap-buddy-hook-test";

  dontUnpack = true;

  nativeBuildInputs = [
    hook
    file
    binutils
    strace
    pkg-config
    patchelf
  ];

  buildInputs = [
    glibc
    zlib
    # glib has transitive deps on pcre2, libffi, etc.
    # This tests that wrapBuddy correctly includes transitive dependencies
    glib
  ];

  # Test runtimeDependencies for dlopen'd libraries
  runtimeDependencies = [ libpng ];

  buildPhase = ''
    runHook preBuild

    # Create a test binary with non-NixOS interpreter
    cat > test.c << 'EOF'
    #include <stdio.h>
    #include <stdlib.h>
    #include <unistd.h>
    #include <dlfcn.h>
    #include <zlib.h>
    #include <glib.h>

    int main(int argc, char **argv) {
        printf("Hello from patched binary!\n");

        // Check /proc/self/exe
        char buf[1024];
        ssize_t len = readlink("/proc/self/exe", buf, sizeof(buf) - 1);
        if (len > 0) {
            buf[len] = '\0';
            printf("/proc/self/exe = %s\n", buf);
        }

        // Check LD_LIBRARY_PATH - should be restored to original or unset
        const char *ldpath = getenv("LD_LIBRARY_PATH");
        printf("LD_LIBRARY_PATH = %s\n", ldpath ? ldpath : "(unset)");

        // Use zlib to verify library loading works (DT_NEEDED)
        printf("zlib version: %s\n", zlibVersion());

        // Use glib to verify transitive dependencies work
        // glib depends on pcre2, libffi, etc. which must be in rpath
        guint major = glib_major_version;
        guint minor = glib_minor_version;
        printf("glib version: %u.%u\n", major, minor);

        // Test dlopen with libpng (runtimeDependencies)
        void *handle = dlopen("libpng.so", RTLD_NOW);
        if (handle) {
            printf("dlopen libpng: success\n");
            dlclose(handle);
        } else {
            printf("dlopen libpng: FAILED - %s\n", dlerror());
            return 1;
        }

        return 0;
    }

    // Reserve space in .text section for the stub
    __asm__(".section .text\n.space 4096, ${nopByte}\n");
    EOF

    # Compile with FHS-style interpreter path
    # Use pkg-config for glib flags
    $CC -o test test.c -lz -ldl $(pkg-config --cflags --libs glib-2.0) \
      -Wl,--dynamic-linker=${fhsInterpreter}

    # Strip RPATH to ensure wrapBuddy is providing library paths, not the linker
    echo "Stripping RPATH from test binary..."
    patchelf --remove-rpath test
    echo "RPATH after stripping: $(patchelf --print-rpath test || echo '(empty)')"

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    cp test $out/bin/test
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    echo "Listing $out/bin:"
    ls -la $out/bin/

    echo "Checking file type..."
    file $out/bin/test

    # Binary should still be ELF (not a script)
    if ! file $out/bin/test | grep -q 'ELF'; then
      echo "ERROR: patched binary is not ELF"
      exit 1
    fi

    # Check that config file exists (hidden with . prefix)
    if [ ! -f "$out/bin/.test.wrapbuddy" ]; then
      echo "ERROR: config file not found"
      exit 1
    fi
    echo "Config file exists: $out/bin/.test.wrapbuddy"


    echo "Checking program headers..."
    readelf -l $out/bin/test | head -50

    echo "Running the patched binary with strace..."
    strace -f $out/bin/test 2>&1 || echo "Binary exited with code $?"

    output=$($out/bin/test 2>&1) || true
    echo "Output was: $output"

    if ! echo "$output" | grep -q "Hello from patched binary!"; then
      echo "ERROR: expected output not found"
      exit 1
    fi

    if ! echo "$output" | grep -q "zlib version:"; then
      echo "ERROR: zlib not loaded correctly"
      exit 1
    fi

    if ! echo "$output" | grep -q "glib version:"; then
      echo "ERROR: glib not loaded correctly (transitive deps missing?)"
      exit 1
    fi

    if ! echo "$output" | grep -q "dlopen libpng: success"; then
      echo "ERROR: runtimeDependencies dlopen failed"
      exit 1
    fi

    # Test LD_LIBRARY_PATH restoration when originally set
    echo "Testing LD_LIBRARY_PATH restoration..."
    export LD_LIBRARY_PATH="/custom/test/path"
    output2=$($out/bin/test 2>&1) || true
    echo "Output with LD_LIBRARY_PATH set: $output2"

    if ! echo "$output2" | grep -q "LD_LIBRARY_PATH = /custom/test/path"; then
      echo "ERROR: LD_LIBRARY_PATH not restored correctly"
      echo "Expected: LD_LIBRARY_PATH = /custom/test/path"
      exit 1
    fi

    # Test without LD_LIBRARY_PATH set
    echo "Testing without LD_LIBRARY_PATH..."
    unset LD_LIBRARY_PATH
    output3=$($out/bin/test 2>&1) || true
    echo "Output without LD_LIBRARY_PATH: $output3"

    # Should either be unset or show the last env var (temporarily used)
    if echo "$output3" | grep -q "LD_LIBRARY_PATH = /nix/store"; then
      echo "ERROR: LD_LIBRARY_PATH leaked Nix paths to program"
      exit 1
    fi
  '';

  meta.platforms = [
    "x86_64-linux"
    "aarch64-linux"
  ];
}
