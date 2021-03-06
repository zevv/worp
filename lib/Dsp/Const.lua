
--
-- Generator which outputs a constant value in the range 0..1, controlled by
-- the 'c' control. Useful for easy mapping of a GUI knob or midi CC to a value.
--

function Dsp:Const(init)

	local c

	return Dsp:Mod({
		description = "Const",
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
