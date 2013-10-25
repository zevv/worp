
-- 
-- A simple polyphonic synth, using DSP code to generate nodes on midi input
--

jack = Jack.new("worp")

-- Voice generator

function voice(f, v)

	local osc1 = Dsp.triangle(f * 0.505)
	local osc2 = Dsp.triangle(f)
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

-- Create polyphonic instrument from the above sound generator

instr, dsp = Dsp.poly(voice)

-- Map the instrument to jack port 'midi' channel 1

jack:midi_map_instr("midi", 1, instr)

-- Use instrument dsp function as sound generator for DSP

jack:dsp("synth", 0, 1, dsp)

-- Connect ports

jack:connect("worp")

-- vi: ft=lua ts=3 sw=3

