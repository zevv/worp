
Fs = require "fluidsynth"
Midi = require "midi"
Mixer = require "mixer"
Metro = require "metro"
Jack = require "jack"
Dsp = require "dsp"

mi = Midi.new("/dev/snd/midiC1D0")
synth = Fs.new("/usr/share/sounds/sf2/FluidR3_GM.sf2")
master = Mixer.new("Master")
headphone = Mixer.new("PCM")
m = Metro:new(100)


synth:program_change(1, 42)

osc = Dsp.osc(1000)
noise = Dsp.noise()

nl = 0
nl2 = 0
d = 0.2
mul = 0

mi:on_pot(1, 3, function(a) osc(a * 100) end)
mi:on_pot(1, 4, function(a) nl = a end)
mi:on_pot(1, 5, function(a) nl2 = a * 0.01 end)
mi:on_pot(1, 6, function(a) d = a * 4 end)

local n = 0

function do_dsp(t)
	local v = math.tanh(osc()  * d) * mul
	local n = noise()
	if n < nl2 then v = v + 0.5 end
	v = v + n * v * nl
	return v, v
end

Jack.new("flop", { "output:left", "output:right" }, do_dsp)


function rl(as)
	return as[math.random(1, #as)]
end


function bip(f)
	print("Bip")
	osc(f)
	dur = m:beat() * 4
	if f == 100 then f = 100 * rl { 1.33, 1.25 } else f = 100 end
	if math.random() < 0.3 then 
		f = f * 8 
		dur = dur / 16 
	end
	at(t_now + dur + 0.3, "bip", f)
end


mul = 0

function bip2(f)
	print("Bip2")
	mul = 1 - mul
	at(t_now + 0.001 + m:beat() / rl { 8, 16, 16}, "bip2", f)
end

--m:at_beat(bip)
--m:at_beat(bip2)


mi:on_key(1, function(onoff, channel, note, vel)
	synth:note(onoff, 1, note, vel)
end)

mi:on_key(5, function(onoff, channel, note, vel)
	local i = ({ 35, 44, 46, 47, 38, 37, 57, 50 })[note-43]
	if i then
		synth:note(onoff, 9, i, vel)
	end
end)

mi:on_pot(1, 1, function(a) master:set(a) end)
mi:on_pot(1, 2, function(a) headphone:set(a) end)

print("ok")

-- vi: ft=lua ts=3 sw=3

