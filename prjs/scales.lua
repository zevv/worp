
Fs = require "fluidsynth"
Chord = require "chord"
Metro = require "metro"
Jack = require "jack"
Dsp = require "dsp"
Midi = require "midi"

synth = Fs.new("/usr/share/sounds/sf2/FluidR3_GM.sf2")

midi = Midi.new("/dev/snd/midiC2D0")

function rl(vs)
	return vs[math.random(1, #vs)]
end

piano = function(onoff, key, vel) synth:note(onoff, 1, key, vel) end
violin = function(onoff, key, vel) synth:note(onoff, 2, key, vel) end
bass = function(onoff, key, vel) synth:note(onoff, 3, key, vel) end

f = Dsp.filter("lp", 1000, 5)

local jack = Jack.new("flop", 
	{ "out_l", "out_r", "in_l", "in_r" }, 
	function(t, i1, i2)
		local v = f(i1)
		return v, v
	end)

midi:on_pot(1, 1, function(channel, cc, v) f("f0", math.exp(v * 10)) end)
midi:on_pot(1, 2, function(channel, cc, v) f("Q", math.pow(2, v*3)) end)
midi:on_pot(1, 3, function(channel, cc, v) f("ft", ({"lp", "hp", "bp", "bs", "ap"})[math.floor(v*4)+1]) end)

jack:disconnect("fluidsynth:l_00", "system:playback_1")
jack:disconnect("fluidsynth:r_00", "system:playback_2")
jack:disconnect("system:capture_1", "flop:in_l")
jack:disconnect("system:capture_2", "flop:in_r")
jack:connect("fluidsynth:l_00", "flop:in_l")
jack:connect("fluidsynth:r_00", "flop:in_r")

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
	local ns = mkchord(40, 73, 2, ms)
	local vel = rl { 0.8, 0.9 }
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

