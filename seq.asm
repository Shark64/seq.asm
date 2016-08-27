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
    BYTE_BUFFER: times 16 db 0; 16byte memory buffer equal to 0

section .text
    global _start

_start:
    mov edx, [rsp] ; pop argc from the stack into rdx

    add rsp, 16; skip over argv[0] in stack

    xor r15d, r15d
    cmp edx, 3; we want 1-2 args (plus the arg 0, the program name)
    je .three_args ; If we don't have 2 args, check if we have 1 instead
    ; If we have 2 args, continue
    mov r15b, 1
    cmp edx, 2
    jne err_invalid_args ; If we don't have 1 arg either, exit
    ; Otherwise, assume that the range starts at 1 and ends at the first arg
    mov rsi, [rsp]
    call atoi
    mov r14, rax
    jmp calc_seq

.three_args:
    ; Convert first arg to int and store in r15
    mov rsi, [rsp]
    call atoi
    mov r15, rax
    ; Convert last arg to int and store in r14
    mov rsi, [rsp+8]
    call atoi
    mov r14, rax

    ; Get sequence in range and print out


; Calculates sequence of numbers in between r15 and r14 and prints out each num
calc_seq:
    mov r13, r15 ; Set r13 (counter) to r15, the starting number

.loop_block:
    ; Print out counter's value
    mov rax, r13
    call itoa
    ; print the arguments
    xor eax, eax
    mov al, 1 ; Syscall number 1 (write)
    mov esi, edi ; Pointer to string at rdi
    mov edi, eax ; 1 = STDOUT
    mov edx, r11d ; Number of chars in string at r11
    syscall

    ; Increment rax's value
    add r13, 1

    cmp r13, r14
    jle .loop_block

exit:
    xor edi, edi
    lea eax, [rdi+60] ; Syscall number 60 (exit)
    syscall

;---------END----------- 


; Takes int in rax, returns pointer to string in rdi and size in r11
itoa:
    mov ebx, 10
    mov edi, BYTE_BUFFER+16 ; Start from the end and add each number in the previous location
    mov [rdi-1],  ebx; 0xA ; Store newline char '\n' in second to last slot
    sub edi, 2
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
    mov [rdi], dl ; Put the ASCII equivalent of this byte in rdi
    sub edi, 1 ; Decrement rdi
    add r11d, 1 ; Increment size
    ; If quotient is 0, leave
    test eax, eax
    jnz .loop_block ; Repeat loop

    add edi, 1 ; fix last decrement

    ; Check the number's sign stored in r10b
    cmp r10b, 1
    je .handle_negative ; If the number is negative, add a '-'
    ; Otherwise, return
    ret
.handle_negative:
    sub edi,1
    add r11d,1
    mov [rdi], byte 0x2D ; Add '-'
    ret

; Takes int string pointer in rsi, returns integer in rax
atoi:
    xor eax, eax ; Set rax to 0
    lea rcx, [rax+0x2D] ; longer opcode for alignment
    xor r10d, r10d ; Set r10b to 0, we'll store the number's sign here

    ; Check if the first char is a '-' indicating a negative number
    cmp cl, byte [rsi]
    ; If it's not continue to the loop
    ; Otherwise, set r10b to 1 for negative and increment rsi
    sete r10b
    add rsi, r10
    xor edx, edx
.loop_block:
    ; Store our current char in cl
    movzx ecx, byte[rsi]
    xor ebx,ebx
    mov eax,edx
    xor edx, edx
    test cl, cl
    setnz bl

    ; Check if numbers are within bounds
    sub cl, byte 0x30
    cmp cl, byte 0x09
    seta dl
    test dl, bl
    jnz err_invalid_args
    ; Multiply value in 'eax' by 10
    lea edx, [rax+rax*4]
    ; Add the current digit to rdx
    lea edx, [rcx+rdx*2]

    ; Increment rsi
    add rsi, rbx
    test bl, bl
    jnz .loop_block

.return_block:
    ; If r10b is 1, make the number negative
    mov ecx, eax
    neg eax		
    cmp r10b, 0x01
    cmovne eax, ecx
    ret

; Prints the string at rdi with size of r11
print:
    xor eax, eax
    mov al, 1 ; Syscall number 1 (write)
    mov esi, edi ; Pointer to string at rdi
    mov edi, eax ; 1 = STDOUT
    mov edx, r11d ; Number of chars in string at r11
    syscall
    ret

err_invalid_args:
    mov edi, INVALID_ARGS
    xor eax, eax
    lea r11d, [rax+19]
    mov al, 1 ; Syscall number 1 (write)
    mov esi, edi ; Pointer to string at rdi
    mov edi, eax ; 1 = STDOUT
    mov edx, r11d ; Number of chars in string at r11
    syscall
    xor eax, eax
    lea edi, [rax+1] ; exit code
    mov al, 60
    syscall
