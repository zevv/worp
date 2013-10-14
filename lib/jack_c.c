
#include <unistd.h>
#include <stdlib.h>
#include <math.h>
#include <signal.h>
#include <string.h>
#include <sys/types.h>

#include <jack/jack.h>
#include <jack/ringbuffer.h>
#include <jack/midiport.h>

#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

#define MAX_PORTS 4
#define RB_SIZE 4096
	
#define sample_t jack_default_audio_sample_t


struct port {
	int flags;
	jack_port_t *port;
	jack_ringbuffer_t *rb;
	struct port *next;
};


struct group {
	int id;
	int fd;
	char *name;
	struct port *port_list;
	struct group *next;
};


struct midi {
	jack_port_t *port;
	int fd;
	struct midi *next;
};


struct jack {
	int fd;
	int direction;
	jack_client_t *client;
	jack_port_t *port[MAX_PORTS];
	jack_ringbuffer_t *rb[MAX_PORTS];
	jack_port_t *midi_in;

	int group_seq;
	struct group *group_list;
	struct midi *midi_list;
};


static int process2(jack_nframes_t nframes, void *arg)
{
	struct jack *jack = arg;
	struct group *group = jack->group_list;
	int len = nframes * sizeof(sample_t);

	while(group) {

		int need_data = 0;

		struct port *port = group->port_list;
		while(port) {

			jack_ringbuffer_t *rb = port->rb;
			jack_port_t *p = port->port;

			if(port->flags == JackPortIsOutput) {

				int avail = jack_ringbuffer_read_space(rb);

				if(avail < len * 2) need_data = 1;

				if(avail >= len) {
					sample_t *buf = jack_port_get_buffer(p, nframes);
					int r = jack_ringbuffer_read(rb, (void *)buf, len);
					if(0 && r != len) printf("underrun\n");
				}

			}

			if(port->flags == JackPortIsInput) {

				if(jack_ringbuffer_write_space(rb) >= len) {
					sample_t *buf = jack_port_get_buffer(p, nframes);
					int r = jack_ringbuffer_write(rb, (void *)buf, len);
					if(0 && r != len) printf("overrun\n");
				}
			}

			port = port->next;
		}

		if(need_data) {
			write(group->fd, " ", 1);
		}
				

		group = group->next;
	}

	struct midi *midi = jack->midi_list;

	while(midi) {
		void *buf = jack_port_get_buffer(midi->port, nframes);
		int n = jack_midi_get_event_count(buf);
		int i;
		for(i=0; i<n; i++) {
			jack_midi_event_t ev;
			jack_midi_event_get(&ev, buf, i);
			write(midi->fd, ev.buffer, ev.size);
		}
		midi = midi->next;
	}

	return 0;
}


static int l_open(lua_State *L)
{
	const char *client_name = luaL_checkstring(L, 1);
	jack_options_t options = JackNullOption;
	jack_status_t status;
	
	struct jack *jack = lua_newuserdata(L, sizeof *jack);
        lua_getfield(L, LUA_REGISTRYINDEX, "jack_c");
	lua_setmetatable(L, -2);
	memset(jack, 0, sizeof *jack);
	
	jack->client = jack_client_open (client_name, options, &status, NULL);
	if (jack->client == NULL) {
		lua_pushnil(L);
		lua_pushfstring(L, "Error creating jack client, status = %x", status);
		return 2;
	}
	
	jack_set_process_callback(jack->client, process2, jack);
	jack_activate (jack->client);
	
	lua_pushnumber(L, jack_get_sample_rate(jack->client));
	lua_pushnumber(L, jack_get_buffer_size(jack->client));
        return 3;
}
	

static int l_gc(lua_State *L)
{
	struct jack *jack = luaL_checkudata(L, 1, "jack_c");
	jack_client_close(jack->client);
	return 0;
}



static int l_add_group(lua_State *L)
{
	struct jack *jack = luaL_checkudata(L, 1, "jack_c");
	const char *name = luaL_checkstring(L, 2);
	int n_in = luaL_checknumber(L, 3);
	int n_out = luaL_checknumber(L, 4);
	int i;
	int fd[2];

	pipe(fd);

	char pname[64];
	struct group *group = lua_newuserdata(L, sizeof *group);
        lua_getfield(L, LUA_REGISTRYINDEX, "jack_group");
	lua_setmetatable(L, -2);
	memset(group, 0, sizeof *group);

	group->name = strdup(name);
	group->id = jack->group_seq ++;
	group->fd = fd[1];

	for(i=0; i<n_in + n_out; i++) {

		struct port *port = calloc(sizeof *port, 1);
		port->flags = (i < n_in) ? JackPortIsInput : JackPortIsOutput;

		snprintf(pname, sizeof(pname), "%s-%s-%d", name, (i<n_in) ? "in" : "out", (i<n_in) ? i+1 : i - n_in+1);

		port->port = jack_port_register(jack->client, pname, JACK_DEFAULT_AUDIO_TYPE, port->flags, 0);
		port->rb = jack_ringbuffer_create(RB_SIZE);

		port->next = group->port_list;
		group->port_list = port;
	}

	group->next = jack->group_list;
	jack->group_list = group;

	lua_pushnumber(L, fd[0]);
	return 2;
}


static int l_add_midi(lua_State *L)
{
	struct jack *jack = luaL_checkudata(L, 1, "jack_c");
	const char *name = luaL_checkstring(L, 2);
	int fd[2];
	char pname[64];

	pipe(fd);

	struct midi *midi = calloc(sizeof *midi, 1);

	snprintf(pname, sizeof(pname), "%s-in", name);
	midi->port = jack_port_register(jack->client, pname, JACK_DEFAULT_MIDI_TYPE, JackPortIsInput, 0);
	midi->fd = fd[1];

	midi->next = jack->midi_list;
	jack->midi_list = midi;

	lua_pushnumber(L, fd[0]);
	return 1;
}



static int l_write(lua_State *L)
{
	struct group *group = luaL_checkudata(L, 1, "jack_group");
	int n = 2;

	struct port *port = group->port_list;

	while(port) {
		if(port->flags == JackPortIsOutput) {
			sample_t s = lua_tonumber(L, n++);
			if(jack_ringbuffer_write_space(port->rb) >= sizeof s) {
				jack_ringbuffer_write(port->rb, (void *)&s, sizeof s);
			}
		}
		port = port->next;
	}

	return 0;
}


static int l_read(lua_State *L)
{
	struct group *group = luaL_checkudata(L, 1, "jack_group");
	int n = 0;

	struct port *port = group->port_list;

	while(port) {
		if(port->flags == JackPortIsInput) {
			sample_t s = 0;
			if(jack_ringbuffer_read_space(port->rb) >= sizeof s) {
				jack_ringbuffer_read(port->rb, (void *)&s, sizeof s);

			}
			lua_pushnumber(L, s);
			n++;
		}
		port = port->next;
	}

	return n;
}


static int l_connect(lua_State *L)
{
	struct jack *jack = luaL_checkudata(L, 1, "jack_c");
	const char *p1 = luaL_checkstring(L, 2);
	const char *p2 = luaL_checkstring(L, 3);

	int r = jack_connect(jack->client, p1, p2);
	lua_pushnumber(L, r);
	return 1;
}


static int l_disconnect(lua_State *L)
{
	struct jack *jack = luaL_checkudata(L, 1, "jack_c");
	const char *p1 = luaL_checkstring(L, 2);
	const char *p2 = luaL_checkstring(L, 3);

	int r = jack_disconnect(jack->client, p1, p2);
	lua_pushnumber(L, r);
	return 1;
}


static int l_list_ports(lua_State *L)
{
	struct jack *jack = luaL_checkudata(L, 1, "jack_c");
	const char **ns = jack_get_ports(jack->client, NULL, NULL, 0);
	if(!ns) return 0;
	int i, j;

	lua_newtable(L);
	for(i=0; ns && ns[i]; i++) {
		jack_port_t *p = jack_port_by_name(jack->client, ns[i]);
		lua_pushnumber(L, i+1);
		lua_newtable(L);

		lua_pushstring(L, ns[i]); lua_setfield(L, -2, "name");
		lua_pushstring(L, jack_port_type(p)); lua_setfield(L, -2, "type");

		lua_newtable(L);
		int flags = jack_port_flags(p);
		if(flags & JackPortIsInput) { lua_pushboolean(L, 1); lua_setfield(L, -2, "input"); }
		if(flags & JackPortIsOutput) { lua_pushboolean(L, 1); lua_setfield(L, -2, "output"); }
		if(flags & JackPortIsPhysical) { lua_pushboolean(L, 1); lua_setfield(L, -2, "physical"); }
		if(flags & JackPortIsTerminal) { lua_pushboolean(L, 1); lua_setfield(L, -2, "terminal"); }
		lua_setfield(L, -2, "flags");

		lua_newtable(L);
		const char **cs = jack_port_get_connections(p);
		for(j=0; cs && cs[j]; j++) {
			lua_pushnumber(L, j+1);
			lua_pushstring(L, cs[j]);
			lua_settable(L, -3);
		}
		free(cs);
		lua_setfield(L, -2, "connections");

		lua_pushvalue(L, -1);
		lua_insert(L, -4);
		lua_settable(L, -3);

		lua_pushvalue(L, -2);
		lua_setfield(L, -2, ns[i]);
	}
	return 1;
}


static struct luaL_Reg jack_table[] = {

        { "open",		l_open },
        { "add_group",		l_add_group },
        { "add_midi",		l_add_midi },

	{ "write",		l_write },
	{ "read",		l_read },
	{ "connect",		l_connect },
	{ "disconnect",		l_disconnect },
	{ "list_ports",		l_list_ports },

        { NULL },
};


int luaopen_jack_c(lua_State *L)
{
	luaL_newmetatable(L, "jack_c");
	lua_pushstring(L, "__gc");
	lua_pushcfunction(L, l_gc);
	lua_settable(L, -3);

	luaL_newmetatable(L, "jack_group");
        luaL_register(L, "jack_c", jack_table);
        return 1;
}

/*
 * End
 */
