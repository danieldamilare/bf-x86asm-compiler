# a brainfuck interpreter
.section .bss
.equ BUFFER_SIZE, 50000
.lcomm BUFFER_DATA, BUFFER_SIZE
.equ TAPE_SIZE, 30000
.lcomm tape, 30000
.lcomm temp, 2

.section .data
PROMPT: .asciz ":> "
ERR: .asciz "\033[31mMissing parenthesis match\n\033[0m"
ERR2: .asciz "\033[31mInvalid source file\n\033[0m"
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
    movl $SYS_READ, %eax
    movl $STDIN, %ebx
    movl $temp, %ecx
    movl $1, %edx
    int $0x80
    test %eax, %eax
    jz flush_done

    movb temp, %bl
    cmpb $'\n', %bl
    jz flush_done
    jmp flush_start

flush_done:
    leave
    ret

# write_descriptor(int desc, char * word, int siz)
write_descriptor:
    .equ SIZ, 16
    .equ WORD, 12
    .equ DESC, 8
    pushl %ebp
    movl %esp, %ebp

    movl $SYS_WRITE, %eax
    movl DESC(%ebp), %ebx
    movl WORD(%ebp), %ecx
    movl SIZ(%ebp), %edx

    int $0x80
    movl %ebp, %esp
    popl %ebp
    ret

# read_descriptor(int desc, char * buf, int siz)
read_descriptor:
    .equ DESC, 8
    .equ BUF, 12
    .equ SIZ, 16
    pushl %ebp
    movl %esp, %ebp

    movl $SYS_READ, %eax
    movl DESC(%ebp), %ebx
    movl BUF(%ebp), %ecx
    movl SIZ(%ebp), %edx
    int $0x80
    leave
    ret

# read_file(char * filename, char * buffer, int siz)
read_file:
    .equ FILENAME, 8
    .equ BUF, 12
    .equ SIZ, 16
    .equ IDX, -4;
    pushl %ebp
    movl %esp, %ebp
    subl $8, %esp
    # open file
    movl $SYS_OPEN, %eax
    movl FILENAME(%ebp), %ebx
    movl $0, %ecx
    movl $0, %edx
    int $0x80
    movl %eax, IDX(%ebp)
    #to do check for error

    pushl SIZ(%ebp)
    pushl BUF(%ebp)
    push %eax
    call read_descriptor
    addl $12, %esp
    pushl %eax
    # todo: check for error
    movl IDX(%ebp), %ebx
    movl $SYS_CLOSE, %eax
    int $0x80

    popl %eax
    movl %ebp, %esp
    popl  %ebp
    ret

_start:
    popl %ecx
    cmpl $1, %ecx  #no file passed
    je REPL
    popl %eax
    popl %eax
    #read file
    pushl $BUFFER_SIZE
    pushl $BUFFER_DATA
    pushl %eax
    call read_file
    addl $12, %esp
    cmpl $0, %eax
    jl FILE_ERROR
    call interpret
    jmp exit_prog

FILE_ERROR:
    pushl $ERR2_SIZE
    pushl $ERR2
    pushl $STDERR
    call write_descriptor
    jmp exit_prog

REPL:
    pushl $3
    pushl $PROMPT
    pushl $STDOUT
    call write_descriptor
    addl $12, %esp

    pushl $BUFFER_SIZE
    pushl $BUFFER_DATA
    pushl $STDIN
    call read_descriptor
    test %eax, %eax
    jz exit_prog
    call interpret
    jmp REPL

# todo: interpret
interpret:
#ecx -> ip, edx -> dp, esi -> bracket depth
    pushl %ebp
    movl %esp, %ebp
    xorl %ecx, %ecx
    xorl %edx, %edx
    xorl %esi, %esi

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
    incb tape(%edx)
    jmp BEGIN

vdec:
    decb tape(%edx)
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
    pushl %ecx
    pushl %edx
    pushl %esi
    leal tape(%edx), %eax
    pushl $1
    pushl %eax
    pushl $STDOUT
    call write_descriptor
    addl $12, %esp

    popl %esi
    popl %edx
    popl %ecx
    jmp BEGIN

input:
    leal tape(%edx), %eax;
    pushl %ecx
    pushl %edx
    pushl %esi
    pushl $1
    pushl %eax
    pushl $STDIN
    call read_descriptor
    addl $12, %esp
    call flush_stdin

    popl %esi
    popl %edx
    popl %ecx
    jmp BEGIN

brac_left:
    cmpb $0, tape(%edx)
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
    pushl $ERR_SIZE #Error: don't care about saving register
    pushl $ERR
    pushl $STDERR
    call write_descriptor
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

    movb tape(%edx), %al
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
