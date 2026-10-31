.section .text.start
.global _start
_start:
 li sp, 16384
 .option push
 .option norelax
 la gp, __global_pointer$
 .option pop
 call main
1: j 1b
