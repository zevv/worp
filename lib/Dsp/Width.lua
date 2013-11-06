
function Dsp:Width(init)

	local a1, a2

	return Dsp:Mod({
		description = "Width",
		controls = {
			{
				id = "width",
				description = "Stereo width",
				min = 0,
				max = 2,
				default = 1,
				fn_set = function(v)
					a1 = math.min(0.5 + v/2, 1)
					a2 = 0.5 - v/2
				end,
			},
		},

		fn_gen = function(_, i1, i2)
			return i1 * a1 + i2 * a2,
			       i2 * a1 + i1 * a2
		end

	}, init)

end

-- vi: ft=lua ts=3 sw=3
