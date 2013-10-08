
return {

	delay = function(s)
		local head = 1
		local buf = {}
		return function(v)
			buf[head] = v
			head = (head % s) + 1
			return buf[head] or 0
		end
	end,

	lp = function(alpha)
		local vavg = 0
		local _alpha = 1 - alpha
		return function(v, n)
			if v == "set" then
				alpha, _alpha = n, 1 - n
				return
			end
			vavg = vavg * alpha + v * _alpha
			return vavg
		end
	end,

	noise = function()
		return math.random
	end,

	osc = function(freq)
		local srate = 44100
		local cos = math.cos
		local i, di = 0, 0
		local fn = function(f)
			if f then 
				di = math.pi * 2 * f/srate 
				return
			end
			i = i + di
			return cos(i)
		end
		fn(freq)
		return fn
	end,

	saw = function(freq)
		local v, dv = 0
		local fn = function(f)
			if f then dv = f/srate end
			v = v + dv
			if v > 1 then v = v - 1 end
			return v
		end
		fn(freq)
		return fn
	end,

	adsr = function(a, d, s, r)
		local v, state, dv = 0, nil, 0
		return function(onoff)
			if onoff == false then
				state, dv = 'r', -s/(srate*r)
			elseif onoff == true then
				state, dv = 'a', 1/(srate*a)
			elseif state == 'a' and v >= 1 then
				state, dv = 'd', -(1-s)/(srate*d)
			elseif state == 'd' and v <= s then
				state, dv = 's', 0
			elseif state == 'r' and v <= 0 then
				state, dv = nil, 0
			end
			v = v + dv
			if v < 0 then v = 0 end
			if v > 1 then v = 1 end
			return v
		end
	end,

	filter = function(ft, f0, Q)

		-- http://www.musicdsp.org/files/Audio-EQ-Cookbook.txt

		local Fs = 44100
		local ft = ft or "lp"
		local f0 = f0 or 1000
		local Q = Q or 1
		local a0, a1, a2, b0, b1, b2
		local x0, x1, x2 = 0, 0, 0
		local y0, y1, y2 = 0, 0, 0

		local function calc()

			local w0 = 2 * math.pi * (f0 / Fs)
			local alpha = math.sin(w0) / (2*Q)
			local cos_w0 = math.cos(w0)

			if ft == "hp" then
				b0, b1, b2 = (1 + cos_w0)/2, -(1 + cos_w0), (1 + cos_w0)/2
				a0, a1, a2 = 1 + alpha, -2*cos_w0, 1 - alpha
			elseif ft == "lp" then
				b0, b1, b2 = (1 - cos_w0)/2, 1 - cos_w0, (1 - cos_w0)/2
				a0, a1, a2 = 1 + alpha, -2*cos_w0, 1 - alpha
			elseif ft == "bp" then
				b0, b1, b2 = Q*alpha, 0, -Q*alpha
				a0, a1, a2 = 1 + alpha, -2*cos_w0, 1 - alpha
			elseif ft == "bs" then
				b0, b1, b2 = 1, -2*cos_w0, 1
				a0, a1, a2 = 1 + alpha, -2*cos_w0, 1 - alpha
			elseif ft == "ap" then
				b0, b1, b2 = 1 - alpha, -2*cos_w0, 1 + alpha
				a0, a1, a2 = 1 + alpha, -2 *cos_w0, 1 - alpha
			else
				error("Unssuported filter type " .. ft)
			end
		end

		calc()

		return function(x0, arg)

			if type(x0) == "string" then
				if x0 == "ft" then ft = arg end
				if x0 == "f0" then f0 = arg end
				if x0 == "Q" then Q = arg end
				return calc()
			end

			y2, y1 = y1, y0
			y0 = (b0 / a0) * x0 + (b1 / a0) * x1 + (b2 / a0) * x2 - (a1 / a0) * y1 - (a2 / a0) * y2
			x2, x1 = x1, x0

			return y0

		end
	
	end,

}


-- vi: ft=lua ts=3 sw=3
