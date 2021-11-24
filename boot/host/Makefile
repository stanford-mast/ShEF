CC = gcc

CFLAGS = -g -Wall

SRCDIR = src
BUILDDIR = bin
OBJDIR = obj

EXE = ed25519

SRC = $(wildcard $(SRCDIR)/*.c)
OBJ = $(SRC:$(SRCDIR)/%.c=$(OBJDIR)/%.o)
DEP = $(wildcard $(SRCDIR)/*.h)

all: $(BUILDDIR)/$(EXE)

$(BUILDDIR)/$(EXE): $(OBJ)
	$(CC) $^ -o $@

$(OBJDIR)/%.o: $(SRCDIR)/%.c $(DEP)
	$(CC) $(CFLAGS) -c $< -o $@

.PHONY: clean

clean:
	rm -f $(OBJDIR)/*.o
