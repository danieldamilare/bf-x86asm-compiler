# a brainfuck interpreter
.section .bss
.equ BUFFER_SIZE, 50000
.lcomm BUFFER_DATA, BUFFER_SIZE
.equ TAPE_SIZE, 30000
.lcomm tape, 30000
.lcomm temp, 2

.section .rodata
PROMPT: .asciz ":> "
ERR: .asciz "\033[31mMissing parenthesis match\n\033[0m"
ERR2: .asciz "\033[31mInvalid source file\n\033[0m"
MODE: .asciz "r"
.equ ERR2_SIZE, 30 
.equ ERR_SIZE, 36 
NL: .asciz "\n"

.section .text
.globl _start
.equ STDOUT, 1
.equ STDIN, 0
.equ STDERR, 2
.equ RDONLY, 1

.equ SYS_WRITE, 4
.equ SYS_READ, 3
.equ SYS_OPEN, 5
.equ SYS_CLOSE, 6

flush_stdin:
    pushl %ebp
    movl %esp, %ebp
flush_start:
    call getchar
    cmpb $'\n', %al
    je flush_done
    test %al, %al
    jz flush_done
    jmp flush_start

flush_done:
    leave
    ret

_start:
    popl %ecx
    cmpl $1, %ecx  #no file passed
    je REPL
    popl %eax
    popl %eax
    and $-16, %esp
    #read file
    pushl $MODE
    pushl %eax
    call fopen
    addl $8, %esp
    test %eax, %eax
    jz FILE_ERROR

    pushl %eax
    pushl $BUFFER_SIZE
    pushl $1
    pushl $BUFFER_DATA
    call fread
    addl $16, %esp
    call interpret
    jmp exit_prog

FILE_ERROR:
    pushl $ERR2
    pushl stderr
    call fprintf
    add $8, %esp
    jmp exit_prog

REPL:
    pushl $PROMPT
    call printf
    pushl stdin
    pushl $BUFFER_SIZE
    pushl $BUFFER_DATA
    call fgets
    addl $12, %esp
    test %eax, %eax
    jz exit_prog
    call interpret
    jmp REPL

# todo: interpret
interpret:
#ecx -> ip, edx -> dp, esi -> bracket depth, edi -> tape
    pushl %ebp
    movl %esp, %ebp
    xorl %ecx, %ecx
    xorl %edx, %edx
    xorl %esi, %esi
    movl $tape, %edi

BEGIN:
    movb BUFFER_DATA(%ecx), %al
    test %al, %al
    jz exit_interpret

    incl %ecx

    cmpb $'+', %al
    je vinc #byte manipulation
    cmpb $'-', %al
    je  vdec
    cmpb $'>', %al
    je pinc# dp_manipulation
    cmpb $'<', %al
    je  pdec
    cmpb $'.', %al
    je output
    cmpb $',', %al
    je input
    cmpb $'[', %al
    je brac_left
    cmpb $']', %al
    je brac_right
    jmp BEGIN

vinc:
    incb (%edi, %edx, 1)
    jmp BEGIN

vdec:
    decb (%edi, %edx, 1)
    jmp BEGIN

pinc:
    incl %edx
    cmpl $TAPE_SIZE, %edx
    jl BEGIN
    xorl %edx, %edx
    jmp BEGIN
pdec:
    decl %edx
    test %edx, %edx
    jns BEGIN
    movl $(TAPE_SIZE -1), %edx
    jmp BEGIN

output:
    subl $16, %esp
    movl %ecx, 0(%esp)
    movl %edx, 4(%esp)
    movl %esi, 8(%esp)
    movl %edi, 12(%esp)
    xorl %eax, %eax
    movb (%edi, %edx, 1), %al
    pushl %eax
    call putchar
    addl $4, %esp

    movl 0(%esp), %ecx
    movl 4(%esp), %edx
    movl 8(%esp), %esi
    movl 12(%esp), %edi
    add $16, %esp
    jmp BEGIN

input:
    subl $16, %esp
    movl %ecx, 0(%esp)
    movl %edx, 4(%esp)
    movl %esi, 8(%esp)
    movl %edi, 12(%esp)

    call getchar
    movb %al, (%edi, %edx, 1)
    call flush_stdin

    movl 0(%esp), %ecx
    movl 4(%esp), %edx
    movl 8(%esp), %esi
    movl 12(%esp), %edi
    add $16, %esp
    jmp BEGIN

brac_left:
    cmpb $0, (%edi, %edx, 1)
    je  skip
    movl %ecx, %eax
    decl %eax
    pushl %eax
    incl %esi
    jmp BEGIN
skip:
    movl $1,  %ebx # use ebx for bracket counter

find_right_brac:
    movb BUFFER_DATA(%ecx), %al
    cmpb $']', %al
    jne  check_left
    decl %ebx
    jmp brac2

check_left:
    cmpb $'[', %al
    jne brac1
    incl %ebx
    jmp brac2

brac1:
    test %al, %al #termination before closing bracket
    jnz  brac2

match_error:   
    pushl $ERR
    pushl stderr
    call fprintf
    addl $8, %esp
    jmp exit_interpret

brac2:
    incl %ecx #move instruction pointer
    cmpl $0, %ebx #finish matching?
    je BEGIN
    jl match_error
    jmp find_right_brac

brac_right:
    test %esi, %esi
    jz match_error
    decl %esi

    movb (%edi, %edx, 1), %al
    test %al, %al
    jnz skip_back
    popl %eax #throwaway the current ip on stack if zero
    jmp BEGIN
skip_back:
    popl %ecx
    jmp BEGIN

exit_interpret:
    movl %ebp, %esp
    popl %ebp
    ret

exit_prog:
    movl $1, %eax
    xorl %ebx, %ebx
    int $0x80
