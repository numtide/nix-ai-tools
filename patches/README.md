# Shared patches

Patches used by more than one package. Reference them from
`packages/<name>/package.nix` with a relative path:

```nix
patch -p1 -d $out/lib/foo < ${../../patches/node-llama-cpp-detectGlibc.patch}
```

## node-llama-cpp-detectGlibc.patch

`node-llama-cpp` probes FHS paths (`/lib`, `/usr/lib`) to detect glibc,
which do not exist on NixOS. Short-circuit the check to always return
true on Linux. Used by `gno` and `qmd`.
