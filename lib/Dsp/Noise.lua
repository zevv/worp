				
-- http://www.taygeta.com/random/gaussian.html

function Dsp:Noise(init)

	local random, sqrt, log = math.random, math.sqrt, math.log
	local type, y1, y2
	
	local function rand()
		return 2 * random() - 1
	end
	
	return Dsp:Mod({
		description = "Noise generator",
		controls = {
			{
				id = "type",
				description = "Noise type",
				type = "enum",
				options = "uniform,gaussian",
				default = "uniform",
				fn_set = function(val) type = val end
			},
		},

		fn_gen = function()

			if type == "uniform" then
				return rand()
			end
		
			if type == "gaussian" then

				local x1, x2, w
				repeat
					x1, x2 = rand(), rand()
					w = x1 * x1 + x2 * x2
				until w < 1
				w = sqrt((-2 * log(w)) / w)
				y1 = x1 * w
				y2 = x2 * w
				return y1
			end
		end,

	}, init)

end

-- vi: ft=lua ts=3 sw=3
