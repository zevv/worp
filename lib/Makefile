
all: jack_c.so

CFLAGS += $(shell pkg-config --cflags jack)
LDFLAGS += $(shell pkg-config --libs jack) 

%.so: %.c
	$(CC) $(CFLAGS) $^ -o $@ $(LDFLAGS)

clean:
	rm -f *.so
