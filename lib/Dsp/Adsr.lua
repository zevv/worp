
--
-- Attack / Decay / Sustain / Release module.
--
-- This module generates an envelope amplitude between 0.0 and 1.0. When the
-- 'vel' argument is set to >0 the envelope generator will start (note on),
-- when 'vel' is set to zero, the generator will go to the decay phase and fall
-- down to zero amplitude (note off)
--

function Dsp:Adsr(init)

	local arg = {
		A = 0,
		D = 0,
		S = 1,
		R = 0,
		on = true,
	}

	local state, v = nil, 0
	local velocity = 0
	local dv_A, dv_D, dv_R, level_S = 0, 0, 0, 1
	local dv = 0

	return Dsp:Mod({
		description = "ADSR envelope generator",
		controls = {
			{
				id = "vel",
				description = "Velocity",
				fn_set = function(val)
					if val > 0 then
						velocity = val
						state, dv = "A", dv_A
					end
					if val == 0 then
						state, dv = "R", dv_R
					end
				end
			}, {
				id = "A",
				description = "Attack",
				max = 10,
				unit = "sec",
				default = 0,
				fn_set = function(val)
					dv_A =  math.min(1/(srate * val), 1)
				end,
			}, {
				id = "D",
				description = "Decay",
				max = 10,
				unit = "sec",
				default = 0,
				fn_set = function(val)
					dv_D = math.max(-1/(srate * val), -1)
				end,
			}, {
				id = "S",
				description = "Sustain",
				default = 1,
				fn_set = function(val)
					level_S = val
				end
			}, {
				id = "R",
				description = "Release",
				max = 10,
				unit = "sec",
				default = 0,
				fn_set = function(val)
					dv_R = math.max(-1/(srate * val), -1)
				end
			}, 
		},
		fn_gen = function()
			if state == "A" and v >= 1 then
				state, dv = "D", dv_D
			elseif state == "D" and v < level_S then
				state, dv = "S", 0
			end
			v = v + dv
			v = math.max(v, 0)
			v = math.min(v, 1)
			return v * velocity
		end,

	}, init)
end

-- vi: ft=lua ts=3 sw=3
