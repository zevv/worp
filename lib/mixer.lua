local ffi = require("ffi")

ffi.cdef [[
   typedef void *snd_mixer_t;
   typedef void *snd_mixer_elem_t;
   typedef void *snd_mixer_class_t;
   typedef struct { char foo[64]; } snd_mixer_selem_id_t;
   int snd_mixer_open(snd_mixer_t **mixer, int mode);
   int snd_mixer_attach(snd_mixer_t *mixer, const char *name);
   int snd_mixer_selem_register(snd_mixer_t *mixer, struct snd_mixer_selem_regopt *options, snd_mixer_class_t **classp);
   int snd_mixer_load(snd_mixer_t *mixer);
   void *malloc(size_t size);
   void snd_mixer_selem_id_set_index(snd_mixer_selem_id_t *obj, unsigned int val);
   void snd_mixer_selem_id_set_name(snd_mixer_selem_id_t *obj, const char *val);
   snd_mixer_elem_t *snd_mixer_find_selem(snd_mixer_t *mixer, const snd_mixer_selem_id_t *id);
   int snd_mixer_selem_set_playback_volume_all(snd_mixer_elem_t *elem, long value);
   size_t snd_mixer_selem_id_sizeof(void);
   int snd_mixer_selem_get_playback_volume_range(snd_mixer_elem_t *elem, long *min, long *max);
]]

local alsa = ffi.load("asound")

local handle = ffi.new("snd_mixer_t *[1]")
local card = "default"

alsa.snd_mixer_open(handle, 0);
alsa.snd_mixer_attach(handle[0], card);
alsa.snd_mixer_selem_register(handle[0], ffi.NULL, ffi.NULL);
alsa.snd_mixer_load(handle[0]);


local function new(name)

   local sid = ffi.new("snd_mixer_selem_id_t *[1]")
   sid = ffi.new("snd_mixer_selem_id_t[1]")

   return {
      set = function(_, v)
         alsa.snd_mixer_selem_id_set_index(sid[0], 0);
         alsa.snd_mixer_selem_id_set_name(sid[0], name);
         local elem = alsa.snd_mixer_find_selem(handle[0], sid[0]);
         local min, max = ffi.new("long[1]", 0), ffi.new("long[1]", 0)
         alsa.snd_mixer_selem_get_playback_volume_range(elem, min, max);
         v = v * (max[0] - min[0]) + min[0]
         alsa.snd_mixer_selem_set_playback_volume_all(elem, v)
      end
   }
end

return {
   new = new
}


-- vi: ft=lua ts=3 sw=3

