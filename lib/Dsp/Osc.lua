
function Dsp:Osc(init)

	local sin = math.sin
	local i, di = 0, 0

	return Dsp:Mod({
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
			return sin(i)
		end
	}, init)
end

-- vi: ft=lua ts=3 sw=3
