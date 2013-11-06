
function Dsp:Const(init)

	local c

	return Dsp:Mod({
		description = "Constant value",
		controls = {
			{
				id = "c",
				description = "Value",
				default = 1,
				fmt = "%0.2f",
				fn_set = function(val) c = val end,
			},
		},

		fn_gen = function()
			return c
		end

	}, init)

end

-- vi: ft=lua ts=3 sw=3
