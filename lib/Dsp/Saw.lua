
function Dsp:Saw(init)

	local v, dv = 0, 0

	return Dsp:Mod({
		description = "Saw tooth oscillator",
		controls = {
			{
				id = "f",
				description = "Frequency",
				max = 20000,
				log = true,
				unit = "Hz",
				default = 440,
				fn_set = function(val)
					dv = 2 * val / srate
				end,
			},
		},
		fn_gen = function()
			v = v + dv
			if v > 1 then v = v - 2 end
			return v
		end
	}, init)

end

-- vi: ft=lua ts=3 sw=3
