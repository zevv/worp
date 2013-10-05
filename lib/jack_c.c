
#include <unistd.h>
#include <stdlib.h>
#include <math.h>
#include <signal.h>
#include <sys/types.h>

#include <jack/jack.h>
#include <jack/ringbuffer.h>

#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

#define JACK_PORTS 2
#define RB_SIZE 16384
	
#define sample_t jack_default_audio_sample_t


struct jack {
	int fd;
	jack_port_t *port[JACK_PORTS];
	jack_client_t *client;
	jack_ringbuffer_t *rb[JACK_PORTS];
};


static int process(jack_nframes_t nframes, void *arg)
{
	int p;
	struct jack *jack = arg;

	int avail = (RB_SIZE - jack_ringbuffer_write_space(jack->rb[0])) / sizeof(sample_t);
	
	if(avail < nframes * 4) {
		write(jack->fd, " ", 1);
	}

	if(avail >= nframes) {
		for(p=0; p<JACK_PORTS; p++) {
			sample_t *out = jack_port_get_buffer (jack->port[p], nframes);
			int need = nframes * sizeof(sample_t);
			int r = jack_ringbuffer_read(jack->rb[p], (void *)out, need);
			if(r != need) printf("underrun\n");
		}
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
	char *port_name[] = { "left", "right" };

	struct jack *jack = lua_newuserdata(L, sizeof *jack);
	
	pipe(fd);

	for(i=0; i<JACK_PORTS; i++) {
		jack->rb[i] = jack_ringbuffer_create(RB_SIZE);
	}

	jack->client = jack_client_open (client_name, options, &status, server_name);
	if (jack->client == NULL) {
		fprintf (stderr, "jack_client_open() failed, "
				"status = 0x%2.0x\n", status);
		if (status & JackServerFailed) {
			fprintf (stderr, "Unable to connect to JACK server\n");
		}
		exit (1);
	}

	jack->fd = fd[1];
	jack_set_process_callback(jack->client, process, jack);

	for(i=0; i<JACK_PORTS; i++) {
		jack->port[i] = jack_port_register (jack->client, port_name[i], JACK_DEFAULT_AUDIO_TYPE, JackPortIsOutput, 0);

		if (jack->port[i] == NULL) {
			fprintf(stderr, "no more JACK ports available\n");
			exit (1);
		}
	}

	if (jack_activate (jack->client)) {
		fprintf (stderr, "cannot activate client");
		exit (1);
	}

	ports = jack_get_ports (jack->client, NULL, NULL, JackPortIsPhysical|JackPortIsInput);
	if (ports == NULL) {
		fprintf(stderr, "no physical playback ports\n");
		exit (1);
	}

	for(i=0; i<JACK_PORTS; i++) {
		if (jack_connect(jack->client, jack_port_name(jack->port[i]), ports[i])) {
			fprintf (stderr, "cannot connect output ports\n");
		}
	}

	free (ports);
	
	lua_pushnumber(L, fd[0]);
	lua_pushnumber(L, jack_get_sample_rate(jack->client));
	lua_pushnumber(L, jack_get_buffer_size(jack->client));
        return 4;
}



static int l_write(lua_State *L)
{
	sample_t s;
	int i;
	struct jack *jack = lua_touserdata(L, 1);

	for(i=0; i<JACK_PORTS; i++) {
		s = lua_tonumber(L, i+2);
		if(jack_ringbuffer_write_space(jack->rb[i]) >= sizeof s) {
			jack_ringbuffer_write(jack->rb[i], (void *)&s, sizeof s);
		}
	}
	return 0;
}



static struct luaL_Reg jack_table[] = {

        { "open",		l_open },
	{ "write",		l_write },

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
