
Jack = require "jack"
Midi = require "midi"
Dsp = require "dsp"

m = Midi.new("/dev/snd/midiC2D0")


local f = Dsp.filter("bp", 1000, 5)

m:on_pot(1, 1, function(channel, cc, v) f("f0", math.exp(v * 10)) end)
m:on_pot(1, 2, function(channel, cc, v) f("Q", math.pow(5, v*3) - 0.99) print(math.pow(5, v*3) - 0.99) end)
m:on_pot(1, 3, function(channel, cc, v) f("ft", ({"lp", "hp", "bp", "bs", "ap", "ls", "hs", "eq"})[math.floor(v*7)+1]) end)
m:on_pot(1, 4, function(channel, cc, v) f("gain", (v - 0.5) * 60) end)

local osc = Dsp.osc(1000)

m:on_key(1, function(onoff, channel, note, vol)
	if onoff then
		f("f0", 440 * math.pow(2, (note-57) / 12))
	end
end)


local r = Dsp.reverb()

Jack.new("flop", 
	{ "output_left", "output_right", "input_l", "input_r" }, 
	function(t, i1, i2)
		return f(math.random()) * 0.2
	end)



-- vi: ft=lua ts=3 sw=3

