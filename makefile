AS = as --32 -g
LD = ld -m elf_i386 
SRC = $(wildcard *.s)
OBJ = $(SRC:.s=.o)
BIN = bf

all: $(BIN)

$(BIN): $(OBJ)
	$(LD) $< -o $@
%.o: %.s
	$(AS) $< -o $@

clean:
	rm -f *.o $(OBJ) $(BIN)
