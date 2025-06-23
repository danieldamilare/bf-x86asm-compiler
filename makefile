AS = as --32 -g
LD = ld -m elf_i386 
LDOPT = -lc -dynamic-linker /lib/ld-linux.so.2
SRC = $(wildcard src/*.s)
OBJ = $(SRC:.s=.o)
BIN = bf

all: $(BIN)

$(BIN): $(OBJ)
	$(LD) $^ -o $@ $(LDOPT)
%.o: %.s
	$(AS) $^ -o $@

clean:
	rm -f *.o $(OBJ) $(BIN)
