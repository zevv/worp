
-- 
-- A simple midi piano
--

Jack = require "jack"
Fs = require "fluidsynth"

jack = Jack.new("worp")
synth = Fs.new("synth")

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

jack:autoconnect("synth:l_00")
jack:autoconnect("synth:r_00")
jack:autoconnect("worp:midi-in")

-- vi: ft=lua ts=3 sw=3

