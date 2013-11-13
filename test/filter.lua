
--
-- Filter test. White noise generator is passed through a CC controlled filter.
--

jack = Jack:new("worp")

f = Dsp:Filter("bp", 1000, 5)
r = Dsp:Reverb()

jack:midi("midi", function(channel, t, d1, d2)
	if t == "cc" then
		local v = d2 / 127
		if d1 == 1 then f("f0", math.exp(v * 10)) end
		if d1 == 2 then f("Q", math.pow(2, v*3)) end
		if d1 == 3 then f("ft", ({"lp", "hp", "bp", "bs", "ap"})[math.floor(v*4)+1]) end
		if d1 == 4 then f("gain", (v - 0.5) * 30) end
	end
end)


jack:dsp("fx", 0, 1, function(t)
	return f(math.random()) * 0.1
end)

jack:connect("worp")


-- vi: ft=lua ts=3 sw=3

