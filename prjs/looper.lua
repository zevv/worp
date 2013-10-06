
Midi = require "midi"
Mixer = require "mixer"
Metro = require "metro"
Jack = require "jack"
Dsp = require "dsp"

mi = Midi.new("/dev/snd/midiC1D0")
master = Mixer.new("Master")

local channels = 8
local len = 44100 * 2
local buf = {}
local vol = {}
for i = 1, channels do
	buf[i] = {}
	vol[i] = 1
	for n = 0, len do
		buf[i][n] = 0
	end
end
local ptr = 0


local rec = nil

Jack.new("flop", 
	{ "output:left", "output:right", "input:l", "input:r" }, 
	function(t, v1, v2)
		if buf[rec] then
			buf[rec][ptr] = buf[rec][ptr] + (v1 or 0)
		end
		ptr = (ptr + 1) % len
		local v = 0
		for i = 1, channels do
			v = v + buf[i][ptr] * vol[i]
		end
		return v, v
	end)

print("Go")

mi:on_key(5, function(onoff, channel, note, vel)
	if onoff then
		if note >= 48 then
			rec = note - 47
		elseif note >= 44 then
			rec = note - 44 + 5
		end
		print("REC", rec)
	else
		rec = nil
	end
end)

mi:on_pot(1, nil, function(chan, pot, val)
	vol[pot] = val
end)

mi:on_pot(5, nil, function(chan, pot, val)
	local r
	if pot > 4 then
		r= pot - 4
	else
		r= pot + 4
	end
	print(r, pot)
	if val > 0 then
		print("CLEAR", r)
		for n = 0, len do
			buf[r][n] = 0
		end
	end
end)

print("ok")

-- vi: ft=lua ts=3 sw=3

