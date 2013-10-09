
--
-- Filter test. White noise generator is passed through a CC controlled filter.
--

Jack = require "jack"
Dsp = require "dsp"

jack = Jack.new("worp")


local f = Dsp.filter("bp", 1000, 5)

jack:midi("midi", function(channel, t, d1, d2)
	if t == "cc" then
		local v = d2 / 127
		if d1 == 1 then f("f0", math.exp(v * 10)) end
		if d1 == 2 then f("Q", math.pow(2, v*3)) end
		if d1 == 3 then f("ft", ({"lp", "hp", "bp", "bs", "ap"})[math.floor(v*4)+1]) end
		if d1 == 4 then f("gain", (v - 0.5) * 30) end
	end
end)

local r = Dsp.reverb()

jack:dsp("fx", 0, 1, function(t)
	return f(math.random()) * 0.2
end)


jack:connect("worp:fx-out-1", "system:playback_1")
jack:connect("worp:fx-out-1", "system:playback_2")
jack:connect("system:midi_capture_2", "worp:midi-in")


-- vi: ft=lua ts=3 sw=3

