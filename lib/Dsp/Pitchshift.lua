
function Dsp:Pitchshift(init)

	local pr, prn, pw = 0, 0, 0
	local size = 0x10000
	local buf = {}
	local nmix = 50
	local mix = 0
	local dmax = 1200 
	local win = 250
	local step = 10
	local factor = 1
	
	local floor = math.floor

	for i = 0, size do buf[i] = 0 end

	local function wrap(i)
		return i % size
	end

	local function read(i) 
		return buf[floor(wrap(i))] 
	end
	
	local function read4(fi)
		local i = floor(fi)
		local f = fi - i
		local a, b, c, d = read(i-1), read(i), read(i+1), read(i+2)
		local c_b = c-b
		return b + f * ( c_b - 0.16667 * (1.-f) * ( (d - a - 3*c_b) * f + (d + 2*a - 3*b)))
	end

	local function find(pf, pt1, pt2)

		local cmax, ptmax = 0, pt1

		for pt = pt1, pt2-win, step do
			local c = 0
			for i = 0, win-1, step do
				c = c + read(pf+i) * read(pt+i)
			end
			if c > cmax then
				cmax = c
				ptmax = pt
			end
		end

		return ptmax
	end
	
	return Dsp:Mod({
		description = "Pitch shift",
		controls = {
			{
				id = "f",
				description = "Factor",
				default = 1,
				min = 0.5,
				max = 2,
				fmt = "%0.2f",
				fn_set = function(val) factor = val end,
			},
		},

		fn_gen = function(_, vi)

			if vi == "factor" then
				factor = arg
				return
			end

			buf[pw] = vi
			local vo = read4(pr)

			if mix > 0 then
				local f = mix / nmix
				vo = vo * f + read4(prn) * (1-f)
				mix = mix - 1
				if mix == 0 then pr = prn end
			end

			if mix == 0 then
				local d = (pw - pr) % size
				if factor < 1 then
					if d > dmax then
						mix = nmix
						prn = find(pr, pr+dmax/2, pr+dmax)
					end
				else
					if d < win or d > dmax * 2 then
						mix = nmix
						prn = find(pr, pr-dmax, pr-win)
					end
				end
			end

			pw = wrap(pw + 1)
			pr = wrap(pr + factor)
			prn = wrap(prn + factor)

			return vo
		end
	}, init)

end

-- vi: ft=lua ts=3 sw=3
