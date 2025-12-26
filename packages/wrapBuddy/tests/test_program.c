// Simple test program for wrap-buddy
// Compiled with FHS interpreter, then patched by wrap-buddy

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

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

    return 0;
}

// Reserve space in .text section for the stub
// x86: 0x90 (NOP), aarch64: 0x1f (part of NOP encoding d503201f)
#if defined(__x86_64__) || defined(__i386__)
__asm__(".section .text\n.space 4096, 0x90\n");
#elif defined(__aarch64__)
__asm__(".section .text\n.space 4096, 0x1f\n");
#endif
