ENTRY(_start)

MEMORY
{
    ROM (rx)  : ORIGIN = 0x00000000, LENGTH = 4K
    RAM (rwx) : ORIGIN = 0x10000000, LENGTH = 4K
}

SECTIONS
{
    .text :
    {
        KEEP(*(.text.start))
        *(.text .text.*)
    } > ROM

    .rodata : ALIGN(4)
    {
        *(.rodata .rodata.* .srodata .srodata.*)
        . = ALIGN(4);
    } > RAM

    .data : ALIGN(4)
    {
        *(.data .data.* .sdata .sdata.*)
        . = ALIGN(4);
    } > RAM

    .bss (NOLOAD) : ALIGN(4)
    {
        __bss_start = .;
        *(.bss .bss.* .sbss .sbss.* COMMON)
        __bss_end = ALIGN(4);
    } > RAM

    __stack_size = 512;
    __stack_top = ORIGIN(RAM) + LENGTH(RAM);

    /DISCARD/ :
    {
        *(.comment)
        *(.note*)
        *(.eh_frame*)
        *(.riscv.attributes)
    }
}

ASSERT(SIZEOF(.text) <= LENGTH(ROM), "instruction ROM exceeds 4 KiB")
ASSERT(__bss_end <= (__stack_top - __stack_size), "data sections leave less than 512 bytes for stack")
