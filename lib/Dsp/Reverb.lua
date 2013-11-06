
-- based on Jezar's public domain C++ sources,

function Dsp:Reverb(init)

	local function allpass(bufsize)
		local buffer = {}
		local feedback = 0
		local bufidx = 0
		return function(input)
			local bufout = buffer[bufidx] or 0
			local output = -input + bufout
			buffer[bufidx] = input + (bufout*feedback)
			bufidx = (bufidx + 1) % bufsize
			return output
		end
	end

	local comb_fb = 0
	local comb_damp1 = 0.5
	local comb_damp2 = 0.5

	local function fcomb(bufsize, feedback, damp)
		local buffer = {}
		local bufidx = 0
		local filterstore = 0
		return function(input)
			local output = buffer[bufidx] or 0
			local filterstore = (output*comb_damp2) + (filterstore*comb_damp1)
			buffer[bufidx] = input + (filterstore*comb_fb)
			bufidx = (bufidx + 1) % bufsize
			return output
		end
	end

	local fixedgain = 0.015
	local scalewet = 3
	local scaledry = 2
	local scaledamp = 0.4
	local scaleroom = 0.28
	local offsetroom = 0.7
	local stereospread = 23

	local comb, allp
	local gain
	local dry, wet1, wet2

	local comb, allp = { 
		{
			fcomb(1116), fcomb(1188), 
			fcomb(1277), fcomb(1356),
			fcomb(1422), fcomb(1491), 
			fcomb(1557), fcomb(1617),
		}, {
			fcomb(1116+stereospread), fcomb(1188+stereospread),
			fcomb(1277+stereospread), fcomb(1356+stereospread),
			fcomb(1422+stereospread), fcomb(1491+stereospread),
			fcomb(1557+stereospread), fcomb(1617+stereospread),
		}
	}, {
		{ 
			allpass(556), allpass(441), allpass(341), allpass(225), 
		}, { 
			allpass(556+stereospread), allpass(441+stereospread), 
			allpass(341+stereospread), allpass(225+stereospread), 
		}
	}

	local arg_wet, arg_dry, arg_room, arg_damp

	return Dsp:Mod({
		description = "Reverb",
		controls = {
			fn_update = function()
				local initialroom = arg_room 
				local initialdamp = arg_damp 
				local initialwet = arg_wet/scalewet
				local initialdry = arg_dry or 0
				local initialwidth = 2
				local initialmode = 0

				local wet = initialwet * scalewet
				local roomsize = (initialroom*scaleroom) + offsetroom
				dry = initialdry * scaledry
				local damp = initialdamp * scaledamp
				local width = initialwidth
				local mode = initialmode

				wet1 = wet*(width/2 + 0.5)
				wet2 = wet*((1-width)/2)

				comb_fb = roomsize
				comb_damp1 = damp
				comb_damp2 = 1 - damp
				gain = fixedgain

			end,
			{
				id = "wet",
				description = "Wet volume",
				default = 0.5,
				fmt = "%0.2f",
				fn_set = function(val) arg_wet = val end
			}, {
				id = "dry",
				description = "Dry volume",
				default = 0.5,
				fmt = "%0.2f",
				fn_set = function(val) arg_dry = val end
			}, {
				id = "room",
				description = "Room size",
				max = 1.1,
				default = 0.5,
				fmt = "%0.2f",
				fn_set = function(val) arg_room = val end
			}, {
				id = "damp",
				description = "Damping",
				default = 0.5,
				fmt = "%0.2f",
				fn_set = function(val) arg_damp = val end
			}
		},
		fn_gen = function(gen, in1, in2)
			in2 = in2 or in1
			local input = (in1 + in2) * gain
			
			local out = { 0, 0 }

			for c = 1, 2 do
				for i = 1, #comb[c] do
					out[c] = out[c] + comb[c][i](input)
				end
				for i = 1, #allp[c] do
					out[c] = allp[c][i](out[c])
				end
			end

			local out1 = out[1]*wet1 + out[2]*wet2 + in1*dry
			local out2 = out[2]*wet1 + out[1]*wet2 + in2*dry

			return out1, out2
		end
	}, init)

end

-- vi: ft=lua ts=3 sw=3
