
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

local function new(fname)


   local settings = fs.new_fluid_settings()
   fs.fluid_settings_setstr(settings, "synth.reverb.active", "yes");
   fs.fluid_settings_setint(settings, "synth.polyphony", 128);
   fs.fluid_settings_setint(settings, "synth.audio-channels", 8);
   fs.fluid_settings_setstr(settings, "audio.jack.autoconnect", "yes");
   fs.fluid_settings_setstr(settings, "audio.jack.multi", "yes");
   fs.fluid_settings_setnum(settings, "synth.gain", 0.5)

   local synth = fs.new_fluid_synth(settings);
   local adriver = fs.new_fluid_audio_driver(settings, synth);
   fs.fluid_synth_sfload(synth, fname, 1);
   --fluid_synth_set_channel_type(synth, 10, CHANNEL_TYPE_DRUM);
   
   return {

      stop = function(_)
         for i = 1, 16 do
            fs.fluid_synth_all_notes_off(f.synth, i);
         end
      end,

      program_change = function(_, chan, prog)
         fs.fluid_synth_program_change(synth, chan, prog)
      end,

      note = function(_, onoff, chan, key, vel)
         if onoff then
            fs.fluid_synth_noteon(synth, chan, key, vel * 127);
         else
            fs.fluid_synth_noteoff(synth, chan, key, vel * 127);
         end
      end,
   }
end


return {
   new = new,
}

-- vi: ft=lua ts=3 sw=3

