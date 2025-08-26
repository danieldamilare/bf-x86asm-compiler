# a brainfuck interpreter
.section .bss
.equ BUFFER_SIZE, 65556
.lcomm BUFFER_DATA, BUFFER_SIZE
.equ TAPE_SIZE, 30000
.lcomm tape, 30000

.lcomm Ops, BUFFER_SIZE
.lcomm arg, BUFFER_SIZE * 4
.lcomm elf_code, 256000


.section .rodata

PROMPT: .asciz ":> "
ERR: .asciz "\033[31mMissing parenthesis match\n\033[0m"
ERR2: .asciz "\033[31mInvalid source file\n\033[0m"
filename: .asciz "a.out"

MODER: .asciz "r"
MODEW: .asciz "w"


NL: .asciz "\n"
.equ START_ADDR, 0x80480000

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

ehdr:
    .byte 0x7f, 'E', 'L', 'F'           # e_indent
    .byte 0x01, 0x01, 0x01, 0x00        # e_idnet
    .rept 8         
    .byte 0                             # e_ident
    .endr
    .word 0x0002                #e_type
    .word 0x0003                #e_machine
    .long 0x00000001            #e_version
    .long START_ADDR + ehdr_size + phdr_size # e_entry is afer entry header and program header
    .long phdr - ehdr           # e_phoff 
    .long 0                     # e_shoff
    .long 0                     # e_flags
    .word ehdr_size              # e_ehsize
    .word phdr_size             # e_phentsize
    .word 1                     # e_phnum
    .rept 3
    .word 0                       # e_shentsize e_shnum e_shstrndx
    .endr

.equ ehdr_size, . - ehdr
phdr:
    .long 1             # p_type
    .long 0             # p_offset
    .long START_ADDR    # p_vaddr
    .long START_ADDR    #p_paddr
    .long 0x00          # file size, to be patched later after code is gnerated
    .long 0x00          # memsiz file size + 30,000 for tabe + 1024 byte for buffered output
    .long 0x07          # p_flags PF_X | PF_W
    .long 0x1000        # p_align not sure what it should be

.equ phdr_size, . - phdr
input: .byte 0xb8, 0x03, 0x00, 0x00, 0x00 # mov, $0x03, %eax
       .byte 0x31, 0xdb                   # xor %ebx, %ebx
       .byte 0x89, 0xf9                   # mov %edi, %ecx
       .byte 0x31, 0xd2                   # xor %edx, %edx
       .byte 0x42                         #inc %edx
       .byte 0xcd, 0x80                   #int $0x80
.equ input_size, . - input


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

.equ ERR2_SIZE, 30 
.equ ERR_SIZE, 36 
.equ O_CREAT, 0x40
.equ O_WRONLY, 0x01
.equ O_TRUNC, 0x200
.equ O_APPEND, 0x400

.equ INC_PTR, $'>'
.EQU DEC_PTR, $'<'
.EQU DEC_DATA, $'-'
.EQU INC_DATA, $'+'
.EQU JZERO, $'['
.EQU JNZERO, $']'


.macro DISPATCH
    movzx (%ebp, %ecx, 1), %eax
    movl %ecx, %ebx
    incl %ecx
    jmp *jmp_table(, %eax, 4)
.endm


_start:
    popl %ecx
    cmpl $1, %ecx  #no file passed
    je FILE_ERROR
    popl %eax
    popl %eax
    and $-16, %esp
    #read file
    pushl $MODER
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

    call compile
    jmp exit_prog

FILE_ERROR:
    pushl $ERR2
    pushl stderr
    call fprintf
    add $8, %esp
    jmp exit_prog

# todo: interpret
compile:
#ecx -> ip, edx -> dp,  edi -> tape %esi -> pointer to elf buffer
    call preprocess
    cmpl $-1, %eax
    je match_error
    xorl %ecx, %ecx
    xorl %edx, %edx
    xorl %esi, %esi
    movl $tape, %edi
    movl $Ops, %ebp
    movl $elf_code, %esi
    addl $5, %esi #skip beginning of els, patch later with mov $TAPE, (%edi)

BEGIN:
    movzx (%ebp, %ecx, 1), %eax
    movl %ecx, %ebx
    incl %ecx
    jmp *jmp_table(, %eax, 4)


vinc:
    movl arg(, %ebx, 4), %eax
    movb $0x80, (%esi)
    movb $0x07, 1(%esi)
    movb %al, 2(%esi)
    addl $3, %esi
    jmp BEGIN

vdec:
    movl arg(, %ebx, 4), %eax
    movb $0x80, (%esi)
    movb $0x27, 1(%esi)
    movb %al, 2(%esi)
    addl $3,  %esi
    jmp BEGIN

pinc:
    movl arg(, %ebx, 4), %eax
    movb $0x81, (%esi)
    movb $0xc7, 1(%esi)
    movl %eax, 2(%esi)
    addl $6, %esi
    jmp BEGIN

pdec:
    movl arg(, %ebx, 4), %eax
    movb $0x81, (%esi)
    movb $0xef, 1(%esi)
    movl %eax, 2(%esi)
    addl $6, %esi
    jmp BEGIN

input:
    subl $8, %esp
    movl %ecx, 0(%esp)
    movl %edx, 4(%esp)

    call getchar
    movb %al, (%edi, %edx, 1)


output:
    pushl %ecx
    pushl %esi
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
    movl %esi, %edx
    popl %esi
    popl %ecx
    DISPATCH


input:
    subl $8, %esp
    movl %ecx, 0(%esp)
    movl %edx, 4(%esp)

    call getchar
    movb %al, (%edi, %edx, 1)

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
    movb (%ebx, %esi, 1), %al
    movzbl %al, %eax
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

    pushl $0755
    pushl $(O_CREAT | O_WRONLY | O_TRUNC | O_APPEND)
    pushl $filename
    call open
    addl $16,  %esp

#write ehdr
    subl $4, %esp
    pushl $ehdr_size
    pushl $ehdr
    pushl %eax
    call write
    popl %eax
    addl $12, %esp

#write phdr
    subl $4, %esp 
    pushl $phdr_size
    pushl $phdr
    pushl %eax
    call write

    pushl $0
    call exit
