# 6502 Debug Routines

These routines provide a way for printing some information during the execution of an assembler programme. It's primary intended for usage with a serial interface, but it's easy to adapt the routines to stream the output to the screen or a printer.

To use the routines, just include debug.asm into your BeebASM source. By using a \_\_DEBUG__ flag you can make outputting debug information optional. For example:

    org &1000

    if __DEBUG__=1
    uart=&FE30
    include "debug.asm"
    endif

    .main   { do something }
            if __DEBUG__ = 1
            pha
            jsr debug_hex
            pla
            endif
            {do more}

When BeebASM is started with -D DEBUG=1 then the debug information will be dispayed, otherwise it is skipped during assembly of the programma.

Please note that you have to take care for saving important registers. Routines like debug_hex will destroy the contents in A, so if you need that information then you have to push and pull the A register like I did in the example.


The main routines are:

__debug_init__\
This routine initializes the output stream. It sets up the communication parameters; by default these are 115200 baud, 8 bits, no parity. If you want to stream the data to another device, e.g. a second monitor then you have to adjust this routine. The base address of the UART must be set in the label 'uart' before calling this routine.\
_Usage:  jsr debug_init_


__debug_msg__\
This routine prints the string following the JSR instruction. All characters are printed until a character is found that has bit 7 set.\
_Usage:  jsr debug_msg\
        equs "This is my message",&0D,&0A\
        nop_


__debug_regs__\
This routine dumps the contents of all 6502 registers. Flags are represented in a binay notation.\
_Usage:  jsr debug_regs_


__debug_mem__\
This routine dumps the content of a memory page. A page is a memory block of 256 bytes. The page number must be set in the Y-register.\
_Usage:  ldy #&01        \ dump the stack\
        jsr debug_mem_


__debug_hex__\
This routine prints the value of register A in a hexadecimal format.\
_Usage:  lda #someValue\
        jsr debug_hex_


__debug_space__\
This routine prints a space. That might me useful when you're printing two or more hex values with the previous routine.\
_Usage:  jsr print_space_


__debug_bits__\
This routine prints the value of register A in a binary format. This routine was primary written as a part of debug_regs but it proves to be useful in dumping register I/O values.\
_Usage:  lda somePort\
        jsr debug_bits_

