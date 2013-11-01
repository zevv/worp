
-- 
-- A simple polyphonic synth, using DSP code to generate nodes on midi input
--

jack = Jack:new("worp")

-- Voice generator

o = Dsp:saw { f = 100 }
f = Dsp:filter()
lfo = Dsp:osc { f = 5 }
rev = Dsp:reverb()

n = Dsp:noise()

Gui:add(f)
Gui:add(o)
Gui:add(lfo)
Gui:add(rev)

jack:dsp("synth", 0, 2, function(t_, i1)
	local v = f(o() * (1+n()*0.3)) * lfo() * 0.1
	return rev(v, v)
end)

-- Connect ports

jack:connect("worp")

-- vi: ft=lua ts=3 sw=3

