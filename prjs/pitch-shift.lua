
--
-- Pitch shifter test. 
--

Jack = require "jack"
Dsp = require "dsp"

jack = Jack.new("worp")

pitchshift = function(factor)

	local buf = {}
	local buf_lp = {}
	local lp = Dsp.filter("lp", "600", 1)
	local p_read_new = 0
	local xfade = 0

	local n_dist = 1500
	local n_search = 400
	local n_window = 50
	local n_xfade = 50
	local size = 2048
	local p_read = size / 2
	local p_write = size / 2

	for i = 0, size do 
		buf[i] = 0 
		buf_lp[i] = 0
	end

	-- Find the position between p_to and p_to+n_search with the best
	-- correlation to p_from
	
	local function search(p_from, p_to)

		p_from = math.floor(p_from) % size
		p_to = math.floor(p_to) % size

		local tmax = 0
		local imax = 0

		for i = 0, n_search - n_window do
			local p1 = p_from
			local p2 = (p_to + i) % size
			local t = 0
			for j = 0, n_window do
				t = t + buf_lp[p1] * buf_lp[p2]
				p1 = (p1 + 1) % size
				p2 = (p2 + 1) % size
			end
			if t > tmax then
				tmax = t
				imax = i
			end
		end

		return (p_to + imax) % size
	end

	-- Read value from buffer using 4 point interpolation
	
	local function read(fi)

		local i = math.floor(fi)
		local count
		local f = fi - i
		local a = buf[(i-1) % size]
		local b = buf[(i+0) % size]
		local c = buf[(i+1) % size]
		local d = buf[(i+2) % size]
		local c_b = c-b
		return b + f * ( c_b - 0.16667 * (1.-f) * ( (d - a - 3*c_b) * f + (d + 2*a - 3*b)))
	end

	return function(v, arg)
		if v == "factor" then
			print(arg)
			factor = arg
			return
		end

		p_write = (p_write + 1) % size
		buf[p_write] = v
		buf_lp[p_write] = lp(v)
		
		p_read = (p_read + factor) % size
		p_read_new = (p_read_new + factor) % size

		if xfade == 0 then
			if factor < 1 then 
				local dist = (p_write - p_read) % size
				if dist >= n_dist then
					p_read_new = search(p_read, p_write - n_search)
					xfade = n_xfade
				end
			else
				local dist = (p_write - p_read) % size
				if dist <= n_xfade or dist > n_dist then
					p_read_new = search(p_read, p_write - n_dist)
					xfade = n_xfade
				end
			end
		end
	
		if xfade > 0 then
			local f1 = xfade / n_xfade
			local f2 = 1 - f1
			xfade = xfade - 1
			if xfade == 0 then p_read = p_read_new end
			return read(p_read) * f1 + read(p_read_new) * f2
		else
			return read(p_read)
		end
	end
end


local f = Dsp.filter("hp", 100, 1)
local s = pitchshift(1.333)

jack:midi("midi", function(channel, t, d1, d2)
	if t == "cc" then
		local v = d2 / 127
		if d1 == 1 then s("factor", v*2 + 0.5) end
	end
end)


jack:dsp("fx", 1, 1, function(t, i)
	return s(f(i))
end)


jack:connect("worp:fx-out-1", "system:playback_1")
jack:connect("worp:fx-out-1", "system:playback_2")
--jack:connect("system:capture_1", "worp:fx-in-1")
jack:connect("system:midi_capture_2", "worp:midi-in")
jack:connect("moc:output0", "worp:fx-in-1")


-- vi: ft=lua ts=3 sw=3

