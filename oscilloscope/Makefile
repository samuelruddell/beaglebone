CROSS_COMPILE?=
BINDIR?=./bin

CFLAGS+= -Wall  -D__DEBUG -O2 -mtune=cortex-a8 -march=armv7-a
LDFLAGS= -lprussdrv -lpthread
OBJDIR=obj
TARGET=$(BINDIR)/oscilloscope

_OBJ = oscilloscope.o
OBJ = $(patsubst %,$(OBJDIR)/%,$(_OBJ))

$(OBJDIR)/%.o: %.c 
	@mkdir -p obj
	$(CROSS_COMPILE)gcc $(CFLAGS) -c -o $@ $<

$(TARGET): $(OBJ) 
	$(CROSS_COMPILE)gcc $(CFLAGS) -o $@ $^ $(LDFLAGS)

.PHONY: clean

clean:
	rm -rf $(OBJDIR)/ *~  $(TARGET)
