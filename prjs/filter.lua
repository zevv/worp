
Jack = require "jack"
Midi = require "midi"
Dsp = require "dsp"

m = Midi.new("/dev/snd/midiC2D0")


local f = Dsp.filter("bp", 1000, 5)

m:on_pot(1, 1, function(channel, cc, v) f("f0", math.exp(v * 10)) end)
m:on_pot(1, 2, function(channel, cc, v) f("Q", math.pow(2, v*3) - 0.99) end)
m:on_pot(1, 3, function(channel, cc, v) f("ft", ({"lp", "hp", "bp", "bs", "ap"})[math.floor(v*4)+1]) end)

Jack.new("flop", 
	{ "output_left", "output_right", "input_l", "input_r" }, 
	function(t, i1, i2)
		local v = f(i1)
		return v, v
	end)



-- vi: ft=lua ts=3 sw=3

