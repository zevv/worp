
Metro = {}    

function Metro:new(bpm, b)
	bpm, b = bpm or 120, b or 4
	local spb = 60 / bpm 
	local spm = spb * b
	local spt = spb / 120
	return {
		t_beat = function()
			return spb
		end,
		t_meas = function()
			return spm
		end,
		at_meas = function(m, ...)
			at((math.floor(t_now / spm) + 1) * spm, ...)
		end,
		at_beat = function(m, ...)
			at((math.floor(t_now / spb) + 1) * spb, ...)
		end
	}
end

-- vi: ft=lua ts=3 sw=3

