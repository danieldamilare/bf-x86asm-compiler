# a brainfuck interpreter
.section .bss
.equ BUFFER_SIZE, 65556
.lcomm BUFFER_DATA, BUFFER_SIZE
.equ TAPE_SIZE, 30000
.lcomm tape, 30000

.lcomm Ops, BUFFER_SIZE
.lcomm arg, BUFFER_SIZE * 4

.section .rodata
PROMPT: .asciz ":> "
ERR: .asciz "\033[31mMissing parenthesis match\n\033[0m"
ERR2: .asciz "\033[31mInvalid source file\n\033[0m"
MODE: .asciz "r"
.equ ERR2_SIZE, 30 
.equ ERR_SIZE, 36 
NL: .asciz "\n"

jmp_table:
    .long exit_interpret
    .rept 42
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
    .long BEGIN
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

.equ INC_PTR, $'>'
.EQU DEC_PTR, $'<'
.EQU DEC_DATA, $'-'
.EQU INC_DATA, $'+'
.EQU JZERO, $'['
.EQU JNZERO, $']'

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
    pushl stdout
    call fflush
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

.macro DISPATCH
    movzx (%ebp, %ecx, 1), %eax
    movl %ecx, %ebx
    incl %ecx
    jmp *jmp_table(, %eax, 4)
.endm

# todo: interpret
interpret:
#ecx -> ip, edx -> dp, esi -> bracket depth, edi -> tape
    call preprocess
    cmpl $-1, %eax
    je match_error
    xorl %ecx, %ecx
    xorl %edx, %edx
    xorl %esi, %esi
    movl $tape, %edi
    movl $Ops, %ebp
BEGIN:
    DISPATCH

vinc:
    movl arg(, %ebx, 4), %eax
    addb %al, (%edi, %edx, 1)
    DISPATCH

vdec:
    movl arg(, %ebx, 4), %eax
    subb %al, (%edi, %edx, 1)
    DISPATCH

pinc:
    addl arg(, %ebx, 4), %edx
    cmpl $TAPE_SIZE, %edx
     jge pinc_reduce
    DISPATCH
pinc_reduce:
    subl $TAPE_SIZE, %edx
    DISPATCH

pdec:
    subl arg(, %ebx, 4), %edx
     js pdec_reduce
    DISPATCH
 pdec_reduce:
     addl $TAPE_SIZE, %edx
     DISPATCH

output:
    pushl %ecx
    movl arg(, %ebx, 4), %ebx
    movl %edx, %esi

output_loop:
    test %ebx, %ebx
    je end_output
    decl %ebx
    xorl %eax, %eax
    movb (%edi, %esi, 1), %al
    pushl %eax
    call putchar
    addl $4, %esp
    jmp output_loop
end_output:
    popl %ecx
    movl %esi, %edx
    DISPATCH


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
    DISPATCH

brac_left:
    cmpb $0, (%edi, %edx, 1)
    je  skip
    DISPATCH
skip:
    movl arg(, %ebx, 4), %ecx
    DISPATCH

match_error:   
    pushl $ERR
    pushl stderr
    call fprintf
    addl $8, %esp
    jmp exit_interpret

brac_right:
    movb (%edi, %edx, 1), %al
    test %al, %al
    jnz skip
    DISPATCH

exit_interpret:
    ret

preprocess:
    pushl %ebp
    movl %esp, %ebp
    subl $16, %esp
    movl $0, -4(%ebp)
    # esi as pointer, ebx as memory pointer, edi as pointer to ops and arg
    leal BUFFER_DATA, %ebx
    xorl %esi, %esi
    xorl %edi, %edi

preprocess_start:
    #read in characters
    # skip characters that are not command
    movzx (%ebx, %esi, 1), %eax
    incl %esi
    testb %al, %al
    je preprocess_exit
    cmpb $127, %al
    jg preprocess_start
    movl jmp_table(,%eax, 4), %ecx
    cmpl $BEGIN, %ecx
    je preprocess_start

    cmpb $'[', %al
    je left_acc
    cmpb $']', %al
    je right_acc
    jmp repeat


left_acc:
    incl -4(%ebp);
    pushl %edi
    movb %al, Ops(, %edi, 1)
    incl %edi
    jmp preprocess_start

right_acc:
    cmpl $0, -4(%ebp)
    je preprocess_error_exit
    popl %ecx
    decl -4(%ebp)
    movb %al, Ops(, %edi, 1)
    movl %ecx, arg(, %edi, 4) #jmp to instruction before matchin
    incl arg(, %edi, 4)
    incl %edi
    movl %edi, arg(, %ecx, 4) #jump to instruction  after matching right bracket
    jmp preprocess_start

repeat:
    xorl %ecx, %ecx
start_repeat:
    cmpb (%ebx, %esi, 1), %al
    jne end_repeat
    incl %ecx
    incl %esi
    jmp start_repeat
end_repeat:
    leal 1(%ecx), %ecx #increment by 1
    movb %al, Ops(,%edi, 1)
    movl %ecx, arg(,%edi, 4)
    incl %edi
    jmp preprocess_start

preprocess_error_exit:
    movl $-1, %eax
    jmp pexit

preprocess_exit:
    xorl %eax, %eax
    movb $0, Ops(, %edi, 1)
pexit:
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
