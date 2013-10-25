
--
-- Some generated music with dsp reverb
--

jack = Jack:new("worp")

linuxsampler = Linuxsampler:new("synth", "/opt/samples")
linuxsampler:reset()

piano = linuxsampler:add("concert_harp.gig", 2)
violin = linuxsampler:add("violins.gig", 5)
bass = linuxsampler:add("basses.gig", 0)

function rl(vs)
	return vs[math.random(1, #vs)]
end

r = Dsp:reverb(0.5, 0.5, 0.8, 0.1)

jack:dsp("fx", 2, 2, function(t, i1, i2)
	return r(i1, i2)
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
	local d = m:beat() * 2
	local ms = Chord:new(0, "minor", c)
	play(bass, 36+ms[1], 0.7, d)
	local ns = mkchord(40, 63, 7, ms)
	local vel = rl { 0.5, 0.6 }
	for i = 1, #ns do
		local n = ns[i]
		play(violin, n, vel/4, d)
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

jack:connect("synth", "system")
---jack:connect("synth", "worp:fx-in")
---jack:connect("worp:fx-out", "system")


-- vi: ft=lua ts=3 sw=3

