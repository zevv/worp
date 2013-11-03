
-- 
-- DSP test
--

jack = Jack:new("worp")
midi = jack:midi("midi")

-- Voice generator

o = Dsp:saw { f = 100 }
f = Dsp:filter()
lfo = Dsp:osc { f = 5 }
rev = Dsp:reverb()

gui = Gui:new("Worp")

n = Dsp:noise()
c = Dsp:const()

f:map_cc(midi, 1, 1)
rev:map_cc(midi, 1, 5)

f:help()

o:control("f"):map_note(midi, 1)

gui:add_mod(o, "Flipje")
gui:add_mod(f)
gui:add_mod(lfo)
gui:add_mod(rev)
gui:add_mod(c, "Noise level")

jack:dsp("synth", 0, 2, function(t_, i1)
	local v = f(o() * (1+n()*c()*10)) * lfo() * 0.1
	return rev(v, v)
end)

-- Connect ports

jack:connect("worp")

-- vi: ft=lua ts=3 sw=3

