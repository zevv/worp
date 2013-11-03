
local ffi = require("ffi")

local fs = ffi.load("fluidsynth")

ffi.cdef [[
	typedef struct fluid_settings_t *fluid_settings_t;
	typedef struct fluid_synth_t * fluid_synth_t;
	typedef struct fluid_audio_driver_t *fluid_audio_driver_t;
	fluid_settings_t *new_fluid_settings(void);
	int fluid_settings_setstr(fluid_settings_t* settings, const char *name, const char *str);
	int fluid_settings_setint(fluid_settings_t* settings, const char *name, int val);
	int fluid_settings_setnum(fluid_settings_t* settings, const char *name, double val);
	fluid_synth_t* new_fluid_synth(fluid_settings_t* settings);
	fluid_audio_driver_t* new_fluid_audio_driver(fluid_settings_t* settings, fluid_synth_t* synth); 
	int fluid_synth_sfload(fluid_synth_t* synth, const char* filename, int reset_presets);
	int fluid_synth_all_notes_off(fluid_synth_t* synth, int chan);
	int fluid_synth_program_change(fluid_synth_t* synth, int chan, int program);
	int fluid_synth_noteon(fluid_synth_t* synth, int chan, int key, int vel);
	int fluid_synth_noteoff(fluid_synth_t* synth, int chan, int key, int vel);
]]


--
-- Send note off to all channels
--

local function reset(fluidsynth)
	for i = 1, 16 do
		fs.fluid_synth_all_notes_off(fluidsynth.synth, i);
	end
end


--
-- Add channel with given program, return instrument function
--

local function add(fluidsynth, prog)

	prog = prog or 1
	local ch = fluidsynth.channels
	fluidsynth.channels = fluidsynth.channels + 1

	fs.fluid_synth_program_change(fluidsynth.synth, ch, prog)

	return function(note, vel)
		if vel > 0 then
			fs.fluid_synth_noteon(fluidsynth.synth, ch, note, vel * 127);
		else
			fs.fluid_synth_noteoff(fluidsynth.synth, ch, note, vel * 127);
		end
	end
end


--
-- Create fluidsynth instance, create and attach jack client with the given
-- name
--

local function new(_, name, fname)

	name = name or "Fluidsynth"

	local fluidsynth = {

		-- methods

		reset = reset,
		add = add,

		-- data
	
		channels = 0,
	}

   local settings = fs.new_fluid_settings()
   fs.fluid_settings_setstr(settings, "audio.jack.id", name)
   fluidsynth.synth = fs.new_fluid_synth(settings);
   local adriver = fs.new_fluid_audio_driver(settings, fluidsynth.synth);
   fs.fluid_synth_sfload(fluidsynth.synth, fname, 1);
   
   return fluidsynth

end


return {
   new = new,
}

-- vi: ft=lua ts=3 sw=3

