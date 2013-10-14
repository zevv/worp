
--
-- Some generated music with effects
--

Fs = require "fluidsynth"
Chord = require "chord"
Metro = require "metro"
Jack = require "jack"
Dsp = require "dsp"

synth = Fs.new("synth")
jack = Jack.new("worp")

function rl(vs)
	return vs[math.random(1, #vs)]
end

piano = function(onoff, key, vel) synth:note(onoff, 1, key, vel) end
violin = function(onoff, key, vel) synth:note(onoff, 2, key, vel) end
bass = function(onoff, key, vel) synth:note(onoff, 3, key, vel) end

f = Dsp.filter("lp", 1000, 1, -3)
r = Dsp.reverb(0.0, 1.0, 1, 0.1)

jack:dsp("fx", 2, 2, function(t, i1, i2)
	return r(f(i1, i2))
end)

jack:midi("midi", function(channel, t, d1, d2)
	if t == "cc" then
		local v = d2 / 127
		if d1 == 1 then f("f0", math.exp(v * 10)) end
		if d1 == 2 then f("Q", math.pow(2, v*3)) end
		if d1 == 3 then f("ft", ({"lp", "hp", "bp", "bs", "ap"})[math.floor(v*4)+1]) end
		if d1 == 4 then f("gain", (v - 0.5) * 30) end
	end
end)

jack:autoconnect("worp:fx-out-1")
jack:autoconnect("worp:fx-out-2")
jack:autoconnect("worp:midi-in")
jack:connect("synth:l_00", "worp:fx-in-1")
jack:connect("synth:r_00", "worp:fx-in-2")

synth:program_change(1, 4)
synth:program_change(2, 68)
synth:program_change(3, 42)


function mkchord(min, max, n, ns)
	local os = {}
	for i = 1, n do
		local o = ns[(i % #ns) + 1]
		local p = o
		while p < min or p >= max do
			p = o + math.random(0, 8) * 12
		end
		os[#os+1] = p
	end
	table.sort(os)
	return os
end

m = Metro:new(60)

function doe(c)
	print(c)
	local d = m:beat() * 2
	local ms = Chord:new(0, "minor", c)
	play(bass, 36+ms[1], 0.7, d)
	local ns = mkchord(40, 93, 7, ms)
	local vel = rl { 0.5, 0.6 }
	for i = 1, #ns do
		local n = ns[i]
		play(violin, n, vel, d)
	end
	local prog = { 
		i7 = { 'vii7', 'v7' },
		vii7 = { 'i7' },
		v7 = { 'i7', 'vi7' },
		vi7 = { 'ii7' },
		ii7 = { 'v7', 'vii7' }
	}
	at(d, "doe", rl(prog[c]))
end


function pulse()
	play(piano, rl { 71, 72, 72, 72, 74, 75, 79, }, rl { 0.6, 0.8 }, m:beat() / 4 )
	at(m:beat() / rl { 1.333333, 2, 4, } , "pulse")
end


m:at_beat("pulse")

m:at_beat("doe", 'i7')


-- vi: ft=lua ts=3 sw=3

