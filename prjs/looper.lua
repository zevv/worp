
Midi = require "midi"
Mixer = require "mixer"
Metro = require "metro"
Jack = require "jack"
Dsp = require "dsp"
Fs = require "fluidsynth"

mi = Midi.new("/dev/snd/midiC2D0")
master = Mixer.new("Master")
synth = Fs.new("/usr/share/sounds/sf2/FluidR3_GM.sf2")

local function pan(v, p)
	return math.max(1 - p, 1) * v, math.max(1 + p, 1) * v
end

local function looper(t)

	local l = {

		-- methods

		run = function(l, v)
			if l.rec then
				l.buf[l.ptr] = l.buf[l.ptr] * 0.5 + v
			end
			l.ptr = (l.ptr + 1) % l.len
			local v = l.buf[l.ptr] * l.vol
			return pan(v, l.pan)
		end,

		-- data
	
		len = 44800 * t,
		buf = {},
		vol = 1,
		pan = 1,
		ptr = 0,
		rec = false,
	}

	for i = 0, l.len do
		l.buf[i] = 0
	end

	return l

end

local channels = 4

local loop = {}

for i = 1, 8 do
	loop[i] = looper(2)
end



local rec = nil

Jack.new("flop", 
	{ "output:left", "output:right", "input:l", "input:r" }, 
	function(t, i1, i2)
		local o1, o2 = 0, 0
		for i = 1,8 do
			local t1, t2 = loop[i]:run(i1)
			o1 = o1 + t1
			o2 = o2 + t2
		end
		return o1, o2
	end)

print("Go")
mi:on_key(1, function(onoff, channel, note, vel)
	synth:note(onoff, 1, note, vel)
end)

mi:on_key(5, function(onoff, channel, note, vel)

	if note >= 48 then
		local i = note - 47
		loop[i].rec = onoff
		print("REC", i, onoff)
	elseif note >= 44 then
		local i = note - 43 
		print("CLEAR", i)
		if onoff then
			for j = 1, #loop[i].buf do
				loop[i].buf[j] = 0
			end
		end
	end
end)

mi:on_pot(1, nil, function(chan, pot, v)
	if pot > 4 then
		loop[pot-4].pan = v * 2 - 1
	else
		loop[pot].vol = v
	end
end)


print("ok")

-- vi: ft=lua ts=3 sw=3

