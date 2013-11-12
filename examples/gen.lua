
j = Jack:new("worp")
l = Linuxsampler:new("ls", "/opt/samples")

m = Metro:new(150, 10)

v = l:add("piano/megapiano.gig", 0)

ns = { 36, 75, 79, 84, 34, 75, 79, 74, 84, 82 }

function one(i)
	play(v, ns[i], ns[i] < 40 and 0.8 or 0.6, 1.0)
	i = (i % #ns) + 1
	at(m:t_beat(), one, i)
end

one(1)

f = Dsp:Filter { type = "bp", Q = 5 }
lfo = Dsp:Osc { f = 4 / m:t_meas() }

j:dsp("fx", 1, 1, function(vi)
	f:set { f = lfo() * 500 + 700 }
	return f(vi)
end)

n = Dsp:Noise()
nf = Dsp:Filter { type = "bp", f = 8000, Q = 5 }
p = Dsp:Pan()
a = Dsp:Adsr { A = 0, D = 0.03, S = 1, R = 0.05 }
r = Dsp:Reverb { }

j:dsp("perc", 0, 2, function()
	return p(r(nf(a() * n())))
end)


function click()
	nf:set { f = rr(8000, 12000) }
	p:set { pan = rr(-1, 1) }
	a:set { vel = rr(0.2, 0.8)  }
	at(0.01, function() a:set { vel = 0 } end)
	at(m:t_beat() * 0.5, "click")
end

click()

j:connect("ls", "worp:fx")
j:connect("worp:fx", "system:playback")
j:connect("worp:perc", "system:playback")

-- vi: ft=lua ts=3 sw=3
