
all: jack_c.so posix.so


CFLAGS += -Wall -Werror
CFLAGS += -shared -fPIC
CFLAGS += $(shell pkg-config --cflags lua5.1 jack)

LDFLAGS += $(shell pkg-config --libs lua5.1 jack) 
LDFLAGS += -lrt -lcrypt


%.so: %.c
	$(CC) $(CFLAGS) $^ -o $@ $(LDFLAGS)

clean:
	rm -f *.so
