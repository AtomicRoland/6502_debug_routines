\ Debug.inc: Several debug routines
\ Debugging information will be send to serial interface
\ This version is for 16C5225 Dual UART on interface A
\ (c) Roland Leurs 2025


zp = &90
uart_rhra = uart+8
uart_thra = uart+8
uart_dlla = uart+8
uart_dlma = uart+9
uart_fcra = uart+10
uart_afra = uart+10
uart_lcra = uart+11
uart_mcra = uart+12
uart_lsra = uart+13
uart_msra = uart+14

.debug_init     jmp _debug_init
.debug_msg      jmp _debug_msg
.debug_regs     jmp _debug_regs
.debug_mem      jmp _debug_mem
.debug_hex      jmp _debug_hex
.debug_space    jmp _debug_space
.debug_bits     jmp _debug_bits


\\ Initialize the serial interface for debugging output
\\ Format: 115200,n,8,1
._debug_init
 pha
 lda uart_lcra  \ enable baudrate divisor
 ora #&80
 sta uart_lcra
 lda #&01       \ set divisor to 1. 115k2
 sta uart_dlla
 lda #&00
 sta uart_dlma
 lda #&03       \ 8 bit, 1 stop, no parity
 sta uart_lcra
 pla
 lda #&01       \ Enable 16 byte fifo buffer
 sta uart_fcra
 lda uart_mcra  \ load current modem control register
 and #&F7       \ set bit 3 to 0
 sta uart_mcra  \ write back to modem control
 rts

\\ Send debug message (string) to serial interface. The string is terminated when a
\\ byte is read with bit7=1. It returns to the first instruction after the string.
._debug_msg         pla                     \ get low byte from stack
                    sta zp                  \ set in workspace
                    pla                     \ get high byte from stack
                    sta zp+1                \ set in workspace
.debugtext_l1       ldy #0                  \ load index
                    inc zp                  \ increment pointer
                    bne debugtext_l2
                    inc zp+1
.debugtext_l2       lda (zp),y              \ load character
                    bmi debugtext_l3        \ jmp if end of string
                    jsr _debug_send_byte    \ send character
                    jmp debugtext_l1        \ next character
.debugtext_l3       jmp (zp)                \ return to calling routine


\\ This routine prints the values of the 6502 registers
._debug_regs        php                     \ save registers
                    pha
                    txa
                    pha
                    tya
                    pha
                    tsx
                    cld
                    jsr debug_msg
                    EQUS "PC   A  X  Y  SP   NV-BDIZC",&0D,&0A,&EA
                    \ print program counter
                    lda &106,x
                    jsr debug_hex
                    lda &105,x
                    jsr debug_hex
                    jsr debug_space
                    \ print A
                    lda &103,x
                    jsr debug_hex
                    jsr debug_space
                    \ print X
                    lda &102,x
                    jsr debug_hex
                    jsr debug_space
                    \ print Y
                    lda &101,x
                    jsr debug_hex
                    \ print SP
                    jsr debug_msg
                    EQUS " 01",&EA
                    txa
                    clc
                    adc #6
                    jsr debug_hex
                    jsr debug_space
                    lda &104,x
                    jsr debug_bits
                    jsr debug_msg
                    EQUB &0D,&0A,&EA
 .debug_restore     pla                     \ restore registers
                    tay
                    pla
                    tax
                    pla
                    plp
                    rts                     \ return

._debug_space
 lda #&20
._debug_send_byte
 pha
.sb1
 lda uart_lsra
 and #&20
 beq sb1
 pla
 sta uart_thra
 rts

\\ Send hex value of A to serial port
._debug_hex         pha                     \ save accu
                    lsr a                   \ shift high nibble to low
                    lsr a
                    lsr a
                    lsr a
                    jsr debughex_l1         \ print nibble
                    pla                     \ restore value
 .debughex_l1       and #&0F                \ remove high nibble
                    cmp #&0A                \ test for hex digit
                    bcc debughex_l2         \ if not then continue
                    adc #6                  \ add 6 for hex letter
 .debughex_l2       adc #&30                \ add &30 for ascii value
                    jmp _debug_send_byte    \ print the digit and return

._debug_bits        ldy #8                  \ load counter
.debug_bits_l1      asl a                   \ shift bit 7 into carry
                    pha                     \ save accu
                    lda #0                  \ preload accu
                    adc #&30                \ loads accu with either '0' or '1'
                    jsr _debug_send_byte    \ send character to serial port
                    pla                     \ restore accu
                    dey                     \ decrement counter
                    bne debug_bits_l1       \ jump if not ready
                    rts
                    
\\ This routine prints a hex dump of the memory page in Y
._debug_mem
 php                    ; save registers
 pha
 txa
 pha
 tya
 pha
 
.debugmem_start
 sta zp+1               ; store load address
 ldy #0
 sty zp

.debugmem_l1
 lda zp+1               ; load the page number
 jsr _debug_hex         ; print it
 tya                    ; transfer the ram-pointer to Accu
 pha                    ; save the value
 jsr _debug_hex         ; print pointer value
 lda #':'               ; print a colon
 jsr _debug_send_byte
 lda #' '               ; print two spaces
 jsr _debug_send_byte
 jsr _debug_send_byte
 ldx #16                ; load counter
.debugmem_l2               
 lda (zp),y             ; load data byte
 jsr _debug_hex         ; print it
 lda #' '               ; print a space
 jsr _debug_send_byte
 iny                    ; increment pointer
 dex                    ; decrement counter
 bne debugmem_l2        ; if not complete line (8 bytes) then do next byte
 pla                    ; get pointer value back
 tay                    ; write to ram-pointer
 ldx #16                ; re-load counter
.debugmem_l3
 lda (zp),y             ; load data byte
 bmi debugmem_dot       ; if negative, print a dot
 cmp #&20               ; check for non printable value below 20
 bmi debugmem_dot       ; print a dot
 cmp #&7F               ; check for backspace
 beq debugmem_dot       ; print a dot
 jsr _debug_send_byte   ; it's a printable character, print it
.debugmem_l4
 iny                    ; increment pointer
 dex                    ; decrement counter
 bne debugmem_l3        ; if not complete line (16 bytes) then do next byte
 lda #&0A               ; send CR/LF
 jsr _debug_send_byte
 lda #&0D
 jsr _debug_send_byte
 cpy #0                 ; check if full page is displayed
 bne debugmem_l1        ; not full page, continue
 jmp debug_restore      ; restore registers and exit

.debugmem_dot
 lda #'.'               ; print a dot
 jsr _debug_send_byte
 jmp debugmem_l4        ; continue
                    
