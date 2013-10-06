
#include <unistd.h>
#include <stdlib.h>
#include <math.h>
#include <signal.h>
#include <string.h>
#include <sys/types.h>

#include <jack/jack.h>
#include <jack/ringbuffer.h>

#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

#define MAX_PORTS 4
#define RB_SIZE 4096
	
#define sample_t jack_default_audio_sample_t


struct jack {
	int fd;
	int direction;
	jack_port_t *port[MAX_PORTS];
	jack_client_t *client;
	jack_ringbuffer_t *rb[MAX_PORTS];
};


static int process(jack_nframes_t nframes, void *arg)
{
	int i;
	struct jack *jack = arg;
	int need_food = 0;
	int len = nframes * sizeof(sample_t);

	for(i=0; i<MAX_PORTS; i++) {
		jack_port_t *p = jack->port[i];
		if(!p) continue;

		jack_ringbuffer_t *rb = jack->rb[i];
		int flags = jack_port_flags(p);

		if(flags & JackPortIsOutput) {

			int avail = jack_ringbuffer_read_space(rb);
			
			if(avail < len * 2) {
				need_food = 1;
			} 

			if(avail >= len) {
				sample_t *buf = jack_port_get_buffer(p, nframes);
				int r = jack_ringbuffer_read(rb, (void *)buf, len);
				if(0 && r != len) printf("underrun\n");
			}
			
		}
	
		if(flags & JackPortIsInput) {
			
			if(jack_ringbuffer_write_space(rb) >= len) {
				sample_t *buf = jack_port_get_buffer(p, nframes);
				int r = jack_ringbuffer_write(rb, (void *)buf, len);
				if(0 && r != len) printf("overrun\n");
			}
		}
	}

	if(need_food) {
		write(jack->fd, " ", 1);
	}

	return 0;
}


static int l_open(lua_State *L)
{
	int i;
	int fd[2];
	const char **ports;
	const char *client_name = luaL_checkstring(L, 1);
	const char *server_name = NULL;
	jack_options_t options = JackNullOption;
	jack_status_t status;

	struct jack *jack = lua_newuserdata(L, sizeof *jack);
	memset(jack, 0, sizeof *jack);
	
	jack->client = jack_client_open (client_name, options, &status, server_name);
	if (jack->client == NULL) {
		fprintf(stderr, "jack_client_open() failed, " "status = 0x%2.0x\n", status);
		if(status & JackServerFailed) {
			fprintf(stderr, "Unable to connect to JACK server\n");
		}
		exit (1);
	}

	pipe(fd);
	jack->fd = fd[1];

	for(i=0; i<MAX_PORTS; i++) {
		lua_pushinteger(L, i+1);
		lua_gettable(L, 2);

		if(lua_isstring(L, -1)) {

			const char *pname = lua_tostring(L, -1);

			jack->rb[i] = jack_ringbuffer_create(RB_SIZE);
			jack->port[i] = jack_port_register(
						jack->client, pname, JACK_DEFAULT_AUDIO_TYPE, 
						pname[0] == 'o' ? JackPortIsOutput : JackPortIsInput, 0);

			if (jack->port[i] == NULL) {
				fprintf(stderr, "Can not register port %s", pname);
				exit (1);
			}

		}
		lua_pop(L, 1);
	}
	
	jack_set_process_callback(jack->client, process, jack);

	if (jack_activate (jack->client)) {
		fprintf (stderr, "cannot activate client");
		exit (1);
	}

	ports = jack_get_ports(jack->client, NULL, NULL, JackPortIsPhysical|JackPortIsInput);
	if (ports) {
		int j = 0;
		for(i=0; i<MAX_PORTS; i++) {
			jack_port_t *p = jack->port[i];
			if(p && jack_port_flags(p) & JackPortIsOutput) {
				fprintf(stderr, "connect %s -> %s\n", jack_port_name(p), ports[j]);
				if (jack_connect(jack->client, jack_port_name(p), ports[j++])) {
					fprintf (stderr, "cannot connect output ports\n");
				}
			}
		}
		free (ports);
	}
	
	ports = jack_get_ports(jack->client, NULL, NULL, JackPortIsPhysical|JackPortIsOutput);
	if (ports) {
		int j = 0;
		for(i=0; i<MAX_PORTS; i++) {
			jack_port_t *p = jack->port[i];
			if(p && jack_port_flags(p) & JackPortIsInput) {
				fprintf(stderr, "connect %s -> %s\n", jack_port_name(p), ports[j]);
				if (jack_connect(jack->client, ports[j++], jack_port_name(p))) {
					fprintf (stderr, "cannot connect output ports\n");
				}
			}
		}
		free (ports);
	}
	
	lua_pushnumber(L, fd[0]);
	lua_pushnumber(L, jack_get_sample_rate(jack->client));
	lua_pushnumber(L, jack_get_buffer_size(jack->client));
        return 4;
}



static int l_write(lua_State *L)
{
	int i;
	struct jack *jack = lua_touserdata(L, 1);

	for(i=0; i<MAX_PORTS; i++) {
		jack_port_t *p = jack->port[i];
		jack_ringbuffer_t *rb = jack->rb[i];

		if(p && jack_port_flags(p) & JackPortIsOutput) {
			sample_t s = lua_tonumber(L, i+2);
			if(jack_ringbuffer_write_space(rb) >= sizeof s) {
				jack_ringbuffer_write(rb, (void *)&s, sizeof s);
			}
		}
	}

	return 0;
}



static int l_read(lua_State *L)
{
	int i;
	int n = 0;
	struct jack *jack = lua_touserdata(L, 1);

	for(i=0; i<MAX_PORTS; i++) {
		jack_port_t *p = jack->port[i];
		jack_ringbuffer_t *rb = jack->rb[i];

		if(p && jack_port_flags(p) & JackPortIsInput) {
			sample_t s = 0;
			if(jack_ringbuffer_read_space(rb) >= sizeof s) {
				jack_ringbuffer_read(rb, (void *)&s, sizeof s);
				lua_pushnumber(L, s);
				n++;
			}
		}
	}

	return n;
}

static struct luaL_Reg jack_table[] = {

        { "open",		l_open },
	{ "write",		l_write },
	{ "read",		l_read },

        { NULL },
};


int luaopen_jack_c(lua_State *L)
{
        luaL_register(L, "jack_c", jack_table);

        return 0;
}

/*
 * End
 */
