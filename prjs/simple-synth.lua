
-- 
-- A simple polyphonic synth, using DSP code to generate nodes on midi input
--

jack = Jack.new("worp")

-- Voice generator, return dsp output function

function voice(f, v)

	local osc1 = Dsp.saw(f * 0.505)
	local osc2 = Dsp.saw(f)
	local lfo = Dsp.osc(8)
	local filt1 = Dsp.filter("lp", 100, 2)
	local adsr = Dsp.adsr(0.1, 0.1, 0.6, 2)
	local adsr2 = Dsp.adsr(1.9, 0.1, 0.6, 1)
	local vel = v

	return function(cmd)

		if cmd == "stop" then
			adsr(false)
			adsr2(false)
			return
		end

		local a = adsr()
		filt1("f0", (adsr2() + lfo() * 0.05) * 1000 + 100)
		if a > 0 then
			return filt1(osc1() + osc2()) * a * vel
		end
	end
end


instr, dsp = Dsp.poly(voice)


-- Handle midi note on and off messages. Generate new voices for new notes and
-- start/stop ADSR's

jack:midi("midi", function(channel, t, d1, d2)
	if t == "noteon" then 
		instr(true, d1, d2)
	end
	if t == "noteoff" then 
		instr(false, d1, d2)
	end
end)


-- Add up the output of all running voices. Voices that are done playing are
-- removed from the list

jack:dsp("synth", 0, 1, dsp)
jack:connect("worp")

-- vi: ft=lua ts=3 sw=3

