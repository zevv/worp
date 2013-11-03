
-- 
-- A simple polyphonic synth, using DSP code to generate nodes on midi input
--

jack = Jack:new("worp")
midi = jack:midi("midi")

gui = Gui:new("worp")


-- Voice generator

function voice()

	local osc = Dsp:osc()
	local adsr = Dsp:adsr { A = 0.1, D = 0.1, S = 0.6, R = 0.5 }
	local velocity = 0

	return Dsp:mkmod({
		id = "synth",
		description = "Sine oscillator",
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
				end
			}, {
				id = "vel",
				description = "Velocity",
				fn_set = function(v)
					adsr:set { vel = v }
				end
			},
		},
		fn_gen = function()
			local v = adsr()
			return osc() * v
		end
	}, init)

end


local v = Dsp:poly { gen = voice }

midi:note(1, function(note, vel)
	local freq = 440 * math.pow(2, (note-57) / 12)
	v:set { f = freq, vel = vel/127 }
end)



jack:dsp("worp", 0, 1, function()
	return v()
end)

gui:add_mod(v)

-- Connect ports

jack:connect("worp")

-- vi: ft=lua ts=3 sw=3

