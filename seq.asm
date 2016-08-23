; Basic implementation of the unix seq command in x86_64 assembly
; Copyright (c) <2016> <Shawn Anastasio>

;Permission is hereby granted, free of charge, to any person obtaining a copy of
;this software and associated documentation files (the "Software"), to deal in
;the Software without restriction, including without limitation the rights to use,
;copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the
;Software, and to permit persons to whom the Software is furnished to do so,
;subject to the following conditions:
;The above copyright notice and this permission notice shall be included in all
;copies or substantial portions of the Software.
;THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
;IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
;FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
;COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
;IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
;CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


section .data
    INVALID_ARGS: db "Invalid arguments!", 0xA
    BYTE_BUFFER: times 10 db 0; 10byte memory buffer equal to 0

section .text
    global _start

_start:
    pop rdx ; pop argc from the stack into rdx

    add rsp, 8; skip over argv[0] in stack

    cmp edx, 3; we want 1-2 args (plus the arg 0, the program name)
    jne .two_args ; If we don't have 2 args, check if we have 1 instead
    ; If we have 2 args, continue

    ; Convert first arg to int and store in r15
    pop rsi
    call atoi
    mov r15, rax

.last_arg:
    ; Convert last arg to int and store in r14
    pop rsi
    call atoi
    mov r14, rax

    ; Get sequence in range and print out
    call calc_seq

    jmp exit

.two_args:
    cmp edx, 2
    jne err_invalid_args ; If we don't have 1 arg either, exit
    ; Otherwise, assume that the range starts at 1 and ends at the first arg
    mov r15d, 1
    jmp .last_arg


; Calculates sequence of numbers in between r15 and r14 and prints out each num
calc_seq:
    mov r13, r15 ; Set r13 (counter) to r15, the starting number

.loop_block:
    ; If r13 > r14, leave the loop
    cmp r13, r14
    jg .return_block
    ; Print out counter's value
    mov rax, r13
    call itoa
    call print

    ; Increment rax's value
    inc r13

    jmp .loop_block

.return_block:
    ret

; Takes int in rax, returns pointer to string in r9 and size in r11
itoa:
    mov ebx, 10
    mov r9, BYTE_BUFFER+10 ; Start from the end and add each number in the previous location
    mov [r9-1], word bx; 0xA ; Store newline char '\n' in second to last slot
    sub r9, 2
    xor r10d, r10d
    lea r11d, [r10+1] ; Store the size in r11 (starts at 1 because of the newline)

    ; Determine if the number is negative, and if so, set r10b to 1
    mov edx, eax
    neg edx
    test eax, eax
    sets r10b ; If it is, set r10b to 1
    cmovs eax, edx ; Make the number positive again for the ASCII conversion

.loop_block:
    xor edx, edx
    ; Divide number by 10 and use remainder to calculate ASCII char value
    div ebx


    add edx, 0x30 ; 0x30 is '0' in ASCII
    mov [r9], dl ; Put the ASCII equivalent of this byte in r9
    sub r9, 1 ; Decrement r9
    add r11, 1 ; Increment size
    ; If quotient is 0, leave
    test eax, eax
    jnz .loop_block ; Repeat loop

    add r9, 1 ; fix last decrement

    ; Check the number's sign stored in r10b
    cmp r10b, 1
    je .handle_negative ; If the number is negative, add a '-'
    ; Otherwise, return
    ret
.handle_negative:
    dec r9
    inc r11
    mov [r9], byte 0x2D ; Add '-'
    ret

; Takes int string pointer in rsi, returns integer in rax
atoi:
    xor eax, eax ; Set rax to 0
    xor ecx, ecx ; Set rcx to 0, we'll store the current digit here
    xor r10d, r10d ; Set r10b to 0, we'll store the number's sign here
    lea ebx, [rax+10] ; Set rbx to 10

    ; Check if the first char is a '-' indicating a negative number
    movzx ecx, byte [rsi]
    cmp cl, byte 0x2D
    ; If it's not continue to the loop
    ; Otherwise, set r10b to 1 for negative
    sete r10b
    add rsi, r10

.loop_block:
    ; Store our current char in cl
    movzx ecx, byte[rsi]
    ; If cl points to terminator, leave loop
    test cl, cl
    jz .return_block

    ; Check if numbers are within bounds
    xor ebx, ebx
    xor edx, edx
    cmp cl, byte 0x30
    setb bl
    cmp cl, byte 0x39
    seta dl 
    add bl,dl
    jnz err_invalid_args
    ; Multiply value in 'eax' by 10
    lea eax, [rax+rax*4]
    sal eax, 1


    ; Convert to number from ASCII
    sub ecx, byte 0x30 ; 0x30 is ASCII for 0

    ; Add the current digit to rax
    add eax, ecx

    ; Increment rsi
    inc rsi

    jmp .loop_block

.return_block:
    ; If r10b is 1, make the number negative
    mov ecx, eax
    neg eax		
    cmp r10b, 1
    cmovne eax, ecx
    ret

; Prints the string at r9 with size of r11
print:
    xor eax, eax
    mov al, 1 ; Syscall number 1 (write)
    mov edi, eax ; 1 = STDOUT
    mov rsi, r9 ; Pointer to string at r9
    mov rdx, r11 ; Number of chars in string at r11
    syscall
    ret

exit:
    xor edi, edi
    lea eax, [rdi+60] ; Syscall number 60 (exit)
    syscall

exit_err:
    xor eax, eax
    lea edi, [rax+1] ; Exit code
    mov al, 60 ; Syscall number 60 (exit)
    syscall

err_invalid_args:
    mov r9, INVALID_ARGS
    mov r11, 19
    call print
    call exit_err
