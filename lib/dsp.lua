
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
}


-- vi: ft=lua ts=3 sw=3
