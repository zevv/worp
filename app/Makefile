
all: posix.so

LDFLAGS += -lrt -lcrypt

%.so: %.c
	$(CC) $(CFLAGS) $^ -o $@ $(LDFLAGS)

clean:
	rm -f *.so
