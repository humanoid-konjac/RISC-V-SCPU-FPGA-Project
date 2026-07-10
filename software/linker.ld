OUTPUT_ARCH(riscv)
ENTRY(_start)

SECTIONS
{
    . = 0;

    .text : ALIGN(4)
    {
        KEEP(*(.text.start))
        *(.text .text.*)
        *(.rodata .rodata.*)
    }

    . = ALIGN(4);
    __rom_end = .;

    .data :
    {
        *(.data .data.*)
        *(.sdata .sdata.*)
    }

    .bss :
    {
        *(.bss .bss.*)
        *(.sbss .sbss.*)
        *(COMMON)
    }

    .got :
    {
        *(.got .got.*)
    }

    /DISCARD/ :
    {
        *(.comment)
        *(.note .note.*)
        *(.eh_frame .eh_frame.*)
    }
}

ASSERT(__rom_end <= 4096, "firmware exceeds the 4 KiB instruction ROM")
ASSERT(SIZEOF(.data) == 0, "initialized data is not supported")
ASSERT(SIZEOF(.bss) == 0, "BSS data is not supported")
ASSERT(SIZEOF(.got) == 0, "GOT data is not supported")
