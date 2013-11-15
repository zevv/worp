
j = Jack:new()

function Synth()

	local o1 = Dsp:Square()
	local o2 = Dsp:Saw()
	local f = Dsp:Filter { f = 800, Q = 8 }
	local adsr  = Dsp:Adsr { A = 0.01, D = 0.01, S = 0.3 }
	local adsr2 = Dsp:Adsr { A = 0.03, D = 1.00, S = 0.1 }
	local pan = Dsp:Pan()

	local depth = 0 + 0.1

	local function instr(note, vel)
		if vel > 0 then depth = vel end
		local freq = n2f(note)
		o1:set { f = freq }
		o2:set { f = freq * 4.0 + 0.2 }
		adsr:set { vel = vel }
		adsr2:set { vel = vel }
		pan:set { pan = rr(-0.8, 0.8) }
	end

	local function gen()
		f:set { f = adsr2() * 3000 * depth + 20}
		return pan(0.1 * adsr() * f(o1() + o2() + math.random() * 0.75))
	end

	return instr, gen
end


instr, gen = Poly(Synth)

rev = Dsp:Reverb { damp = 0.2 }

j:dsp("synth", 0, 2, function()
	return rev(gen())
end)


j:connect("worp")

function play2(instr, note, vel, dur)
	play(instr, note, vel, dur)
	at(0.18*3, play, instr, note + 12, vel * 0.9, dur)
end

ns = { 34, 22, 70, 34, 65, 34, 17, 74, 36, 72, 53, 58 }

function appreg(i)

	local n = ns[i]
	local v = (i % 5) == 1 and  0.9 or 0.7
	play2(instr, n, v, 0.16)

	at(0.18, function()
		appreg((i % #ns) + 1)
	end)
end


appreg(1)

-- vi: ft=lua ts=3 sw=3
