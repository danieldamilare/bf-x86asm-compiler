# a brainfuck interpreter
.section .bss
.equ BUFFER_SIZE, 65556
.lcomm BUFFER_DATA, BUFFER_SIZE

.lcomm Ops, BUFFER_SIZE
.lcomm arg, BUFFER_SIZE * 4
.lcomm elf_code, 512000
.lcomm code_size, 4

.section .rodata
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

input_code: .byte 0xb8, 0x03, 0x00, 0x00, 0x00 # mov, $0x03, %eax
       .byte 0x31, 0xdb                   # xor %ebx, %ebx
       .byte 0x89, 0xf9                   # mov %edi, %ecx
       .byte 0x31, 0xd2                   # xor %edx, %edx
       .byte 0x42                         #inc %edx
       .byte 0xcd, 0x80                   #int $0x80
.equ input_size, . - input_code

.section .data
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


compile:
#ecx -> ip, edx -> dp,  edi -> tape %esi -> pointer to elf buffer
    call preprocess
    cmpl $-1, %eax
    je match_error
    xorl %ecx, %ecx
    xorl %edx, %edx
    movl $Ops, %ebp
    movl $elf_code, %esi
    addl $5, %esi #skip beginning of elf, patch later with mov $TAPE, (%edi)

BEGIN:
    movzx (%ebp, %ecx, 1), %eax
    movl %ecx, %ebx
    incl %ecx
    jmp *jmp_table(, %eax, 4)


vinc:
    movl arg(, %ebx, 4), %eax
    movw $0x0780, (%esi)
    movb %al, 2(%esi)
    addl $3, %esi
    jmp BEGIN

vdec:
    movl arg(, %ebx, 4), %eax
    movw $0x2f80, (%esi)
    movb %al, 2(%esi)
    addl $3,  %esi
    jmp BEGIN

pinc:
    movl arg(, %ebx, 4), %eax
    movw $0xc781, (%esi)
    movl %eax, 2(%esi)
    addl $6, %esi
    jmp BEGIN

pdec:
    movl arg(, %ebx, 4), %eax
    movw $0xef81, (%esi)
    movl %eax, 2(%esi)
    addl $6, %esi
    jmp BEGIN

input:
    pushl %ecx
    movl $input_size, %ecx
    movl %esi, %edi
    movl $input_code, %esi
    rep movsb
    movl %edi, %esi
    popl %ecx
    jmp BEGIN

output:
    movl arg(, %ebx, 4), %eax
    movl $0xbd46f631, (%esi)
    movl %eax,  4(%esi)
    movl $0x04b0c031, 8(%esi)
    movl $0x8943db31, 12(%esi)
    movl $0x42d231f9, 16(%esi)
    movl $0x80cd, 20(%esi) 
    movl $0xe87cf539, 22(%esi) #jump back -22 (0xea) 
    addl $26, %esi
    jmp BEGIN

brac_left:
    movw $0x3f80, (%esi)
    movb $00, 2(%esi)
    movw $0x840f, 3(%esi)
    addl $5, %esi
    pushl %esi
    addl $4, %esi
    jmp BEGIN
   
brac_right:
    popl %edi
    movw $0x3f80, (%esi)
    movb $00, 2(%esi)
    movw $0x850f, 3(%esi)
    movl %edi, %eax
    addl $4, %eax #skip [ past jump offset
    subl %esi, %eax
    subl $9, %eax # offset starts at the end of jne instruction
    movl %eax, 5(%esi)
    addl $9, %esi  #move esi buffer to the next available fed
    movl %esi, %eax    
    subl %edi, %eax #subtract target address from current address
    subl $4, %eax  # the real target address is at the end of the instruction which is patch + 4
    movl %eax, (%edi)
    jmp BEGIN

match_error:   
    pushl $ERR
    pushl stderr
    call fprintf
    addl $8, %esp
    jmp ext_inter

exit_interpret:
# write the exit system call
    movl $0xc031db31, (%esi)
    movb $0x40, 4(%esi)
    movw $0x80cd, 5(%esi)
    addl $7, %esi

#calculate file size and write to program header structure
    movl %esi, %eax
    subl $elf_code, %eax
    addl $phdr_size, %eax
    addl $ehdr_size, %eax
    movl $phdr, %ebx
    #write p_filesiz
    movl %eax, 16(%ebx)
    movl %eax, %ecx
    movl %eax, code_size
    addl $START_ADDR, %ecx
    #wrtie movl $TAPE, %edi
    movl $elf_code, %edi
    movb $0xbf, (%edi)
    movl %ecx, 1(%edi)
    #write p_memsiz
    addl $30000, %eax
    movl %eax, 20(%ebx)
ext_inter:
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
    ja preprocess_start
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
    popl %eax
    addl $12, %esp

    # write emitted code
    subl $4, %esp
    pushl code_size
    pushl $elf_code
    pushl %eax
    call write
    popl %eax
    addl $12, %esp

    #close file descriptor
    pushl %eax
    call close

    xorl %eax, %eax
    xorl %ebx, %ebx
    inc %eax
    int $0x80

