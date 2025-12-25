# wrapBuddy Makefile
#
# Builds loader.bin and stub.bin as flat binaries for freestanding execution.
# On x86_64, also builds 32-bit variants (loader32.bin, stub32.bin).
#
# Variables:
#   CC          - C compiler (default: cc)
#   OBJCOPY     - Binary extraction tool (default: objcopy)
#   PREFIX      - Installation prefix (default: /usr/local)
#   LIBDIR      - Library directory (default: $(PREFIX)/lib/wrap-buddy)
#   DESTDIR     - Staging directory for packaging (optional)
#
# Usage (Nix):
#   make LIBDIR=$out && make install LIBDIR=$out
#
# Usage (traditional packaging):
#   make
#   make install DESTDIR=/tmp/staging

CC ?= cc
OBJCOPY ?= objcopy
PREFIX ?= /usr/local
LIBDIR ?= $(PREFIX)/lib/wrap-buddy

# Auto-detect target architecture from compiler
TARGET := $(shell $(CC) -dumpmachine 2>/dev/null)

# Determine native arch flags
ifneq (,$(findstring aarch64,$(TARGET)))
  # aarch64: use tiny code model for truly PC-relative addressing (adr not adrp)
  ARCH_FLAGS = -mcmodel=tiny
  BUILD_32BIT =
else ifneq (,$(findstring x86_64,$(TARGET)))
  ARCH_FLAGS =
  BUILD_32BIT = 1
else
  ARCH_FLAGS =
  BUILD_32BIT =
endif

# Freestanding flags - no libc, no system headers
CFLAGS_BASE = -Wall -nostdlib -nostdinc -fPIC -fno-stack-protector \
              -fno-exceptions -fno-unwind-tables \
              -fno-asynchronous-unwind-tables -fno-builtin -Os -Iinclude

# Linker flags for flat binary output
LDFLAGS = -Wl,-T,preamble.ld -Wl,-e,_start -Wl,-Ttext=0

# Native flags
CFLAGS_NATIVE = $(CFLAGS_BASE) $(ARCH_FLAGS) $(LDFLAGS)

# 32-bit flags (only used on x86_64)
CFLAGS_32 = $(CFLAGS_BASE) -m32 $(LDFLAGS)

# Header dependencies
HEADERS = include/wrap-buddy/*.h include/wrap-buddy/arch/*.h preamble.ld

# Targets
NATIVE_BINS = loader.bin stub.bin
ifdef BUILD_32BIT
  ALL_BINS = $(NATIVE_BINS) loader32.bin stub32.bin
else
  ALL_BINS = $(NATIVE_BINS)
endif

.PHONY: all clean install

all: $(ALL_BINS)

# Native loader
loader.elf: loader.c $(HEADERS)
	$(CC) $(CFLAGS_NATIVE) -o $@ loader.c

loader.bin: loader.elf
	$(OBJCOPY) -O binary --only-section=.all $< $@

# Native stub
stub.elf: stub.c $(HEADERS)
	$(CC) $(CFLAGS_NATIVE) -DLOADER_PATH='"$(LIBDIR)/loader.bin"' -o $@ stub.c

stub.bin: stub.elf
	$(OBJCOPY) -O binary --only-section=.all $< $@

# 32-bit loader (x86_64 only)
loader32.elf: loader.c $(HEADERS)
	$(CC) $(CFLAGS_32) -o $@ loader.c

loader32.bin: loader32.elf
	$(OBJCOPY) -O binary --only-section=.all $< $@

# 32-bit stub (x86_64 only)
stub32.elf: stub.c $(HEADERS)
	$(CC) $(CFLAGS_32) -DLOADER_PATH='"$(LIBDIR)/loader32.bin"' -o $@ stub.c

stub32.bin: stub32.elf
	$(OBJCOPY) -O binary --only-section=.all $< $@

install: $(ALL_BINS)
	install -d $(DESTDIR)$(LIBDIR)
	install -m 644 $(ALL_BINS) $(DESTDIR)$(LIBDIR)/

clean:
	rm -f *.elf *.bin
