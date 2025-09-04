AS      = as --32 -g
LD      = ld -m elf_i386
LDOPT   = -lc -dynamic-linker /lib/ld-linux.so.2

SRC_DIR = src
OBJ_DIR = obj

COMP_SRC = $(SRC_DIR)/bf_compiler.s
COMP_OBJ = $(OBJ_DIR)/bf_compiler.o
COMP_BIN = bf_compiler

INT_SRC  = $(SRC_DIR)/bf_interpreter.s
INT_OBJ  = $(OBJ_DIR)/bf_interpreter.o
INT_BIN  = bf_interpreter

all: compiler interpreter

compiler: $(COMP_BIN)
interpreter: $(INT_BIN)

$(COMP_BIN): $(COMP_OBJ)
	$(LD) $^ -o $@ $(LDOPT)

$(INT_BIN): $(INT_OBJ)
	$(LD) $^ -o $@ $(LDOPT)

$(OBJ_DIR)/%.o: $(SRC_DIR)/%.s | $(OBJ_DIR)
	$(AS) $< -o $@

$(OBJ_DIR):
	mkdir -p $(OBJ_DIR)

clean:
	rm -rf $(OBJ_DIR) $(COMP_BIN) $(INT_BIN)

.PHONY: all compiler interpreter clean

