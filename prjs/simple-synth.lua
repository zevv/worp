
-- 
-- A simple polyphonic synth, using DSP code to generate nodes on midi input
--

Jack = require "jack"
Dsp = require "dsp"

jack = Jack.new("worp")
osc = Dsp.osc()
adsr = Dsp.adsr(0.1, 0.2, 0.6, 0.3)
rev = Dsp.reverb(0.5, 0.5, 0.9, 0.6)
vel = 1


-- Voice generator, return a function to start, stop and generate sound.

function voice()

	local osc1 = Dsp.saw(100)
	local osc2 = Dsp.saw(100)
	local lfo = Dsp.osc(2)
	local filt1 = Dsp.filter("lp", 100, 2)
	local adsr = Dsp.adsr(0.1, 0.1, 0.6, 0.1)
	local adsr2 = Dsp.adsr(0.9, 0.1, 0.6, 0.1)
	local vel = 0

	return function(cmd, f, v)
		if cmd == "noteon" then
			osc1(f * 0.505)
			osc2(f * 1.000)
			vel = v
			adsr(true)
			adsr2(true)
			return
		elseif cmd == "noteoff" then
			adsr(false)
			adsr2(false)
			return
		else
			local a = adsr()
			filt1("f0", (adsr2() + lfo() * 0.1) * 1000 + 100)
			if a > 0 then
				return filt1(osc1() + osc2()) * a
			end
		end
	end
end


-- Handle midi note on and off messages. Generate new voices for new notes and
-- start/stop ADSR's

vs = {}

jack:midi("midi", function(channel, t, d1, d2)
	if channel == 1 then
		if t == "noteon" then 
			local f = 440 * math.pow(2, (d1-57) / 12)
			vel = d2 / 127
			local v = voice()
			v("noteon", f, vel)
			vs[d1] = v
		end
		if t == "noteoff" then 
			vs[d1]("noteoff")
		end
	end
end)


-- Add up the output of all running voices. Voices that are done playing are
-- removed from the list

jack:dsp("synth", 0, 2, function(t)
	local o = 0
	for note, v in pairs(vs) do
		local p = v()
		if p then
			o = o + p * 0.1
		else
			vs[note] = nil
		end
	end
	return rev(o)
end)

jack:connect("worp:synth-out-1", "system:playback_1")
jack:connect("worp:synth-out-2", "system:playback_2")
jack:connect("system:midi_capture_2", "worp:midi-in")

-- vi: ft=lua ts=3 sw=3

