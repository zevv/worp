
--
-- The Square module generates a square wave at the given frequency and pwm
-- offset. The output range is -1.0 .. +1.0
--

function Dsp:Square(init)

	local saw = Dsp:Saw()
	local pwm = 0.5

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
					saw:set { f = val }
				end
			}, {
				id = "pwm",
				description = "PWM",
				default = 0,
				fn_set = function(val)
					pwm = val
				end
			},
		},
		fn_gen = function()
			return saw() < pwm and -1 or 1
		end
	}, init)
end

-- vi: ft=lua ts=3 sw=3
