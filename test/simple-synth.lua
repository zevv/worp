
-- 
-- A simple polyphonic synth, using DSP code to generate nodes on midi input
--

jack = Jack:new("worp")
gui = Gui:new("worp")
fs = Fluidsynth:new("worp", "/usr/share/sounds/sf2/FluidR3_GM.sf2")


midi = jack:midi("midi")

c = Dsp:Const()
gui:add_mod(c)

midi:map_mod(1, 1, c)

-- Voice generator module

function voice()

	local osc = Dsp:Saw()
	local filter = Dsp:Filter { type = "lp" }
	local adsr = Dsp:Adsr { A = 0.03, D = 0.03, S = 0.6, R = 0.6 }
	local adsr2 = Dsp:Adsr { A = 0.3, D = 0.8, S = 0.5, R = 0.6 }
	local lfo = Dsp:Osc { f = 6 }
	local freq

	return Dsp:Mod({
		id = "synth",
		description = "Simple synth",
		controls = {
			{
				id = "f",
				description = "Frequency",
				max = 20000,
				log = true,
				unit = "Hz",
				default = 440,
				fn_set = function(v)
					osc:set { f = v }
					freq = v
				end
			}, {
				id = "vel",
				description = "Velocity",
				fn_set = function(v)
					adsr:set { vel = v }
					adsr2:set { vel = v == 0 and 0 or 1 }
				end
			},
		},
		fn_gen = function()
			filter:set { f = adsr2() * (lfo() * 0.1 + 1) * freq * c() * 5 }
			return filter(osc()) * adsr()
		end
	}, init)

end


v, synth = Dsp:Poly { gen = voice }

midi:map_instr(1, synth)

jack:dsp("worp", 0, 1, function()
	return v()
end)

-- Connect ports

jack:connect("worp")

-- vi: ft=lua ts=3 sw=3

