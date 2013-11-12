
--
-- The Osc module generates a cosine wave at the given frequency. The output
-- range is -1.0 .. +1.0
--

function Dsp:Osc(init)

	local sin = math.sin
	local i, di = 0, 0

	return Dsp:Mod({
		id = "osc",
		description = "Sine oscillator",
		controls = {
			{
				id = "f",
				description = "Frequency",
				max = 20000,
				log = true,
				unit = "Hz",
				default = 440,
				fn_set = function(val)
					di = val * math.pi * 2 / srate 
				end
			},
		},
		fn_gen = function()
			i = i + di
			return cos(i)
		end
	}, init)
end

-- vi: ft=lua ts=3 sw=3
