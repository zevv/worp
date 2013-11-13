
m = Metro:new(60)

jack = Jack:new("worp")

linuxsampler = Linuxsampler:new("synth", "/opt/samples")
linuxsampler:reset()

harp = linuxsampler:add("concert_harp.gig", 2)
violin = linuxsampler:add("violins.gig", 5)
bass = linuxsampler:add("basses.gig", 0)

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


function playchord(c)
	local d = m:t_beat() * 2
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
	at(d, "playchord", rl(prog[c]))
end


function pulse()
	play(harp, rl { 71, 72, 72, 72, 74, 75, 79, }, rl { 0.6, 0.8 }, m:t_beat() / 4 )
	at(m:t_beat() / rl { 1.333333, 2, 4, } , "pulse")
end

pulse()

math.randomseed(5)

m:at_beat("pulse")
m:at_beat("playchord", 'i7')

jack:connect("synth", "system")


-- vi: ft=lua ts=3 sw=3

