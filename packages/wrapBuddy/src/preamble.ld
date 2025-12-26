/* Linker script for flat binary (stub and loader) */
PHDRS
{
  all PT_LOAD;
}

SECTIONS
{
  . = 0;
  .all : {
    *(.text._start)
    *(.text .text.*)
    *(.trampoline)
    *(.rodata .rodata.* .rodata.str1.1)
    *(.data .data.* .data.trampoline)
    *(.bss .bss.*)
  } :all
  /DISCARD/ : {
    *(.comment)
    *(.note*)
    *(.eh_frame*)
    *(.dynamic)
    *(.dynsym)
    *(.dynstr)
    *(.gnu*)
    *(.rela*)
  }
}
