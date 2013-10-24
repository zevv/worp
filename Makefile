
CFLAGS += -Wall -Werror
CFLAGS += -shared -fPIC
CFLAGS += $(shell pkg-config --cflags luajit)
CFLAGS += -g

LDFLAGS += $(shell pkg-config --libs luajit)
LDFLAGS += -lrt -lcrypt
LDFLAGS += -g

default: 
	make all

%:
	make -C app $@
	make -C lib $@

export CFLAGS LDFLAGS

