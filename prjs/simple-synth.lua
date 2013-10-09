
-- 
-- A simple synth with reverb and CC controllable filter
--

Jack = require "jack"
Dsp = require "dsp"
Fs = require "fluidsynth"

jack = Jack.new("worp")
synth = Fs.new("synth")

local rev = Dsp.reverb(0.8, 0.7, 0.9, 0.2)
local f = Dsp.filter("lp", 500)

jack:dsp("rev", 2, 2, function(t, in1, in2)
	local v = f(in1)
	return rev(v, v)
end)


jack:midi("midi", function(channel, t, d1, d2)
	if channel == 1 then
		if t == "noteon" then 
			synth:note(true, channel, d1, d2 / 127) 
		end
		if t == "noteoff" then 
			synth:note(false, channel, d1, d2 / 127) 
		end
		if t == "cc" and d1 == 1 then
			f("f0", math.exp(d2 / 127 * 10))
		end
	end
end)

synth:note(true, 9, 42, 1)

jack:connect("worp:rev-out-1", "system:playback_1")
jack:connect("worp:rev-out-2", "system:playback_2")
jack:connect("worp:rev-out-2", "system:playback_2")
jack:connect("synth:l_00", "worp:rev-in-1")
jack:connect("synth:r_00", "worp:rev-in-2")
jack:connect("system:midi_capture_2", "worp:midi-in")


-- vi: ft=lua ts=3 sw=3

