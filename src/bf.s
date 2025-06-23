# a brainfuck interpreter
.section .bss
.equ BUFFER_SIZE, 65556
.lcomm BUFFER_DATA, BUFFER_SIZE
.equ TAPE_SIZE, 30000
.lcomm tape, 30000
.lcomm temp, 2

.lcomm Ops, BUFFER_SIZE
.lcomm arg, BUFFER_SIZE

.section .rodata
PROMPT: .asciz ":> "
ERR: .asciz "\033[31mMissing parenthesis match\n\033[0m"
ERR2: .asciz "\033[31mInvalid source file\n\033[0m"
MODE: .asciz "r"
.equ ERR2_SIZE, 30 
.equ ERR_SIZE, 36 
NL: .asciz "\n"

jmp_table:
    .rept 43
    .long BEGIN #skip
    .endr
    .long  vinc
    .long  input
    .long  vdec
    .long  output
    .rept 13
    .long BEGIN #skip
    .endr
    .long pdec
    .long pdec
    .long pinc
    .rept 28
    .long BEGIN #skip
    .endr
    .long brac_left
    .long BEGIN 
    .long brac_right
    .rept 34
    .long BEGIN
    .endr

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
    addl $12, %esp
    call fclose
    add $4, %esp

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
    call preprocess
    xorl %ecx, %ecx
    xorl %edx, %edx
    xorl %esi, %esi
    movl $tape, %edi
    movl $BUFFER_DATA, %ebp

BEGIN:
    movb (%ebp, %ecx, 1), %al
    test %al, %al
    jz exit_interpret

    incl %ecx
    
    movzbl %al, %eax
    cmpl $127, %eax
    ja BEGIN
    jmp *jmp_table(, %eax, 4)

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
    subl $8, %esp
    movl %ecx, 0(%esp)
    movl %edx, 4(%esp)
    xorl %eax, %eax
    movb (%edi, %edx, 1), %al
    pushl %eax
    call putchar
    addl $4, %esp

    movl 0(%esp), %ecx
    movl 4(%esp), %edx
    add $8, %esp
    jmp BEGIN

input:
    subl $8, %esp
    movl %ecx, 0(%esp)
    movl %edx, 4(%esp)

    call getchar
    movb %al, (%edi, %edx, 1)
flush:
    call  getchar
    test %al, %al
    jz flush_done
    cmpb $'\n', %al
    jnz flush
flush_done:
    movl 0(%esp), %ecx
    movl 4(%esp), %edx
    add $8, %esp
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
    movb (%ebp, %ecx, 1), %al
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
    ret

preprocess:
    pushl %ebp
    movl %esp, %ebp
    # esi as pointer, ebx as memory
    leal BUFFER_DATA, %ebx
    xorl %esi, %esi

preprocess_start:
    #read in characters
    # skip characters that are not command
    movb (%ebx, %esi, 1), %al
    movzbl %al, %eax
    incl %esi
    cmpb $127, %al
    jg preprocess_start
    movl jmp_table(,%eax, 1), ecx
    cmpl $BEGIN, %ecx
    je preprocess_start

    cmpb $'+', %al
    je inc_acc
    cmpb $'-', %al
    je inc_acc

    cmpb $'>', %al
    je ptr_acc
    cmpb $'<', %al
    je ptr_acc

    cmpb $'[', %al
    je left_acc
    cmpb $']', %brac
    je right_acc
    jmp repeat

preprocess_exit:
    movl %ebp, %esp
    popl %ebp
    ret


exit_prog:
    pushl stdout
    call fflush
    add $4, %esp
    movl $1, %eax
    xorl %ebx, %ebx
    int $0x80
