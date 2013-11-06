
Metro = {}    

function Metro:new(bpm, b)
	bpm, b = bpm or 120, b or 4
	local spb = 60 / bpm 
	local spm = spb * b
	local spt = spb / 120
	return {
		beat = function()
			return spb
		end,
		meas = function()
			return spm
		end,
		at_meas = function(m, ...)
			at((math.floor((t_now + 0.001) / spm) + 1) * spm - t_now, ...)
		end,
		at_beat = function(m, ...)
			at((math.floor((t_now + 0.001) / spb) + 1) * spb - t_now, ...)
		end
	}
end

-- vi: ft=lua ts=3 sw=3
