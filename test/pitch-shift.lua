
--
-- Pitch shifter. Inspired by http://dafx.labri.fr/main/papers/p007.pdf
--

jack = Jack:new("worp")

midi = jack:midi(1)

gui = Gui:new("worp")
s = Dsp:pitchshift()

gui:add_mod(s)
midi:map_mod(1, 1, s)


jack:dsp("fx", 1, 1, function(t, i)
	return s(i)
end)


jack:connect("worp")


-- vi: ft=lua ts=3 sw=3

