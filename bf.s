;a brainfuck interpreter
.section .bss
.equ BUFFER_SIZE, 1024
.lcomm BUFFER_DATA, BUFFER_SIZE

.section .data
PROMPT: asciz ":>"
ERR: asciz "Invalid bf source code\n"

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

;strlen(char * word)
strlen:
    pushl %ebp
    movl %esp, %ebp
    movl 8(%ebp), %eax
    movl $0, %edx

LOOP:
    cmpl $0,  (%eax)
    je EXIT_LOOP
    incl %edx
    incl %eax
    jmp LOOP
EXIT_LOOP:
    movl %edx, %eax
    movl %ebp, %esp
    popl %ebp
    ret

; write_descriptor(int desc, char * word, int siz)
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

; read_descriptor(int desc, char * buf, int siz)
read_descriptor:
    .equ DESC, 8
    .equ BUF, 12
    .equ SIZ, 16
    pushl %ebx
    movl %esp, %ebp

    movl $SYS_READ, %eax
    movl DESC(%ebp), %ebx
    movl BUF(%ebp), %ecx
    movl SIZ(%ebp), %edx
    int 0x80h
    leave
    ret

; read_file(char * filename, char * buffer, int siz)
read_file:
    .equ FILENAME, 8
    .equ BUF, 12
    .equ SIZ, 16
    .equ IDX, -4;
    subl $8, %esp
    ;open file
    movl $SYS_OPEN, %eax
    movl FILENAME(%ebp), %ebx
    movl $0, %ecx
    movl $0, %edx
    int $0x80
    movl %eax, IDX(%ebp)
    ;to do check for error

    pushl SIZ(%ebp)
    pushl BUF(%ebp)
    push %eax
    call read_descriptor
    addl $12, %esp
    ;todo: check for error
    movl IDX(%ebp), %ebx
    movl $SYS_CLOSE, %eax
    int 0x80
    
    movl %ebp, %esp
    popl  %ebp
    ret

_start:
    .equ ARGCC, 8
    .equ FILE, 12
    pushl %ebp
    movl %esp, %ebp
    movl ARGCC(%ebp), %eax
    cmpl $1, %eax  #no file passed
    je REPL

    ;read file
    pushl FILE(%ebp)
    pushl BUFFER_DATA
    pushl BUFFER_SIZE
    call read_file
    addl $12, %esp

    jmp interpret

REPL:
    pushl $PROMPT
    call strlen
    add $4, %esp

    pushl %eax
    pushl $PROMPT
    pushl $STDOUT
    call write_descriptor

    pushl BUFFER_SIZE
    pushl BUFFER_DATA
    pushl $STDIN
    call read_descriptor

    jmp interpret

;todo: interpret
interpret:
    
exit_prog:
    movl $1, %eax
    int 0x80
