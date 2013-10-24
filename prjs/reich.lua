
--
-- Some generated music with effects
--

ls = Linuxsampler.new("/opt/samples")
jack = Jack.new()

piano = ls:add("piano", "megapiano.gig")
violin = ls:add("violin", "megapiano.gig", 0)

jack:connect("piano")
jack:connect("violin")

jack = Jack.new()

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


math.randomseed(os.time())
ns = mkchord(40, 83, 5, Chord:new(0, "minor", 'i7'))

d = { 1, 2, 1, 2, 2, 2, 1 }

function doe(instr, a, ns, i, dur)
	local d = dur / d[i]
	play(instr, a + ns[i], i == 1 and 0.7 or 0.5, d/2)
	at(d, "doe", instr, a, ns, (i%#ns)+1, dur)
end

doe(piano, 0, ns, 1, 0.6)
doe(violin, -12, ns, 1, 0.62)



-- vi: ft=lua ts=3 sw=3

