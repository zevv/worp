
-- 
-- A simple midi piano using fluidsynth
--

jack = Jack.new("worp")
fs = Fluidsynth.new("synth", "/usr/share/sounds/sf2/FluidR3_GM.sf2")

piano = fs:add(1)

jack:midi("midi", function(channel, t, d1, d2)
	if t == "noteon" then 
		piano(true, d1, d2 / 127) 
	end
	if t == "noteoff" then 
		piano(false, d1, d2 / 127) 
	end
end)

jack:connect("synth")
jack:connect("worp")

-- vi: ft=lua ts=3 sw=3

