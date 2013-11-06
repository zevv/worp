
function Dsp:Pan(init)

	local v1, v2

	return Dsp:Mod({
		description = "Pan",
		controls = {
			{
				id = "pan",
				description = "Pan",
				min = -1,
				max = 1,
				default = 0,
				fn_set = function(val) 
					v1 = math.min(1 + val, 1)
					v2 = math.min(1 - val, 1)
				end,
			},
		},

		fn_gen = function(_, i1, i2)
			i2 = i2 or i1
			return i1*v1, i2*v2
		end

	}, init)

end

-- vi: ft=lua ts=3 sw=3
