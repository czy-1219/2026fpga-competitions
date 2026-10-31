ENTRY(_start)
MEMORY { ram (rwx) : ORIGIN = 0, LENGTH = 16K }
SECTIONS {
 .text : { *(.text.start) *(.text*) *(.rodata*) } > ram
 .data : { *(.data*) *(.sdata*) } > ram
 .bss : { *(.bss*) *(.sbss*) *(COMMON) } > ram
 __global_pointer$ = . + 0x800;
 ASSERT(. < 14336, "Firmware leaves less than 2 KiB stack")
}
