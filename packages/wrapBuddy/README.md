# wrapBuddy

*"The best way to spread Christmas cheer is wrapping ELFs for all to hear!"*
— Buddy, probably

wrapBuddy is your enthusiastic helper for getting stubborn ELF binaries to run
on NixOS. Just like Buddy the Elf bringing holiday magic to New York City,
wrapBuddy brings NixOS compatibility to binaries that refuse to cooperate.

## Why wrapBuddy instead of autoPatchelfHook?

autoPatchelfHook rewrites ELF headers (interpreter path, RPATH) which can be
error-prone and may break binaries that, have unusual ELF layouts.

wrapBuddy takes a different approach: it patches the entry point to load a stub
that sets up the environment, then restores the original code before running.
The ELF headers remain mostly untouched (only PT_INTERP → PT_NULL).

Use wrapBuddy when autoPatchelfHook fails or breaks the binary.

## How it works

wrapBuddy uses a two-stage loader architecture:

1. **Stub** (~350 bytes): Written to the binary's entry point at build time.
   Loads the external loader and jumps to it.

1. **Loader** (~4KB): Pre-compiled flat binary that:

   - Reads config from `.<binary>.wrapbuddy`
   - Restores original entry point bytes
   - Sets up `DT_RUNPATH` in a new .dynamic section for library resolution
   - Loads the NixOS dynamic linker (ld.so)
   - Jumps directly to original entry point

```
Binary start
    │
    ▼
┌─────────┐     ┌─────────┐     ┌─────────┐
│  Stub   │────▶│ Loader  │────▶│  ld.so  │────▶ main()
└─────────┘     └─────────┘     └─────────┘
                     │
                     │ Sets DT_RUNPATH in memory
                     │ Loads NixOS ld.so
                     │ Restores entry bytes
                     ▼
```

The RPATH is set by creating a new .dynamic section in memory with a
`DT_RUNPATH` entry. This avoids modifying environment variables, so child
processes inherit a clean environment.

## Usage

```nix
{ stdenv, wrapBuddy, ... }:

stdenv.mkDerivation {
  # ...

  nativeBuildInputs = [ wrapBuddy ];

  # The hook runs in fixupPhase and patches all ELF binaries
  # that have a non-NixOS interpreter (e.g., /lib64/ld-linux-x86-64.so.2)
}
```

## Requirements

The binary must have sufficient space at the entry point for the stub
(~350 bytes). Most binaries have enough padding, but if not, you can add
space during compilation:

```c
// Add padding in .text section for the stub
__asm__(".section .text\n.space 4096, 0x90\n");
```

## Files created

For each patched binary `<name>`, the hook creates:

- `.<name>.wrapbuddy` - Hidden config file with original entry bytes,
  interpreter path, and library paths

## Limitations

- Linux only (x86_64 and aarch64)
- Requires space at entry point for stub
- Binary must be writable during fixup phase

## Debugging

If a patched binary fails to start, check:

1. Config file exists: `ls -la .<binary>.wrapbuddy`
1. Interpreter is correct: `cat .<binary>.wrapbuddy | xxd | head`
1. Run with strace: `strace -f <binary>`

The loader prints debug info to stderr if it fails to load.
