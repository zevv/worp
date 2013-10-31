
-- 
-- A simple polyphonic synth, using DSP code to generate nodes on midi input
--

jack = Jack:new("worp")



-- Voice generator

function voice(f, v)

	local osc1 = Dsp:saw { f = f * 0.505 }
	local osc2 = Dsp:saw { f = f }
	local lfo = Dsp:osc { f = 8 }
	local filt1 = Dsp:filter { type = "lp", f = 100, Q = 2 }
	local adsr = Dsp:adsr { A = 0.1, D = 0.1, S = 0.6, R = 2 }
	local adsr2 = Dsp:adsr { A = 1.9, D = 0.1, S = 0.6, R = 1 }
	local vel = v
	local r = Dsp:noise { type = 'gaussian' }

	Gui:add(adsr)

	return function(cmd)

		if cmd == "stop" then
			adsr:set { on = false }
			adsr2:set { on = false }
			return
		end

		local a = adsr()
		filt1:set { f = (adsr2() + lfo() * 0.05) * 1000 + 100 }
		if a > 0 then
			return filt1(osc1() + osc2()) * a * vel
		end
	end
end

-- Create polyphonic instrument from the above sound generator

instr, dsp = Dsp:poly(voice)

-- Map the instrument to jack port 'midi' channel 1

jack:midi_map_instr("midi", 1, instr)

-- Use instrument dsp function as sound generator for DSP

jack:dsp("synth", 0, 1, dsp)

-- Connect ports

jack:connect("worp")

-- vi: ft=lua ts=3 sw=3

