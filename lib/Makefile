
all: jack_c.so posix.so


CFLAGS += -Wall -Werror
CFLAGS += -shared -fPIC
CFLAGS += $(shell pkg-config --cflags luajit jack)
CFLAGS += -g

LDFLAGS += $(shell pkg-config --libs luajit jack) 
LDFLAGS += -lrt -lcrypt
LDFLAGS += -g


%.so: %.c
	$(CC) $(CFLAGS) $^ -o $@ $(LDFLAGS)

clean:
	rm -f *.so
