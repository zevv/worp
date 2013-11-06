
-- 
-- DSP test
--

jack = Jack:new("worp")
midi = jack:midi("midi")

-- Voice generator

o = Dsp:Saw { f = 100 }
f = Dsp:Filter()
lfo = Dsp:Osc { f = 5 }
rev = Dsp:Reverb()

gui = Gui:new("Worp")

n = Dsp:Noise()
c = Dsp:Const()

midi:map_mod(1, 1, f)
midi:map_mod(1, 5, rev)

f:help()

gui:add_mod(o, "Osc")
gui:add_mod(f)
gui:add_mod(lfo, "LFO")
gui:add_mod(rev)
gui:add_mod(c, "Noise")

jack:dsp("synth", 0, 2, function(t_, i1)
	local v = f(o() * (1+n()*c()*10)) * lfo() * 0.1
	return rev(v, v)
end)

-- Connect ports

jack:connect("worp")

-- vi: ft=lua ts=3 sw=3

