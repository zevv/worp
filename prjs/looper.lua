
-- 
-- Simple 4 track looper controlled by Akai MKP mini
--

jack = Jack:new("worp")

local function pan(v, p)
	return math.max(1 - p, 1) * v, math.max(1 + p, 1) * v
end

local function looper(t)

	local l = {

		-- methods

		run = function(l, v)
			if l.rec then
				l.buf[l.ptr] = l.buf[l.ptr] * 0.5 + v
			end
			l.ptr = (l.ptr + 1) % l.len
			local v = l.buf[l.ptr] * l.vol
			return pan(v, l.pan)
		end,

		-- data
	
		len = 44800 * t,
		buf = {},
		vol = 1,
		pan = 1,
		ptr = 0,
		rec = false,
	}

	for i = 0, l.len do
		l.buf[i] = 0
	end

	return l

end

local channels = 4

local loop = {}

for i = 1, 8 do
	loop[i] = looper(2)
end



local rec = nil

jack:dsp("looper", 1, 2, function(t, i1)
	local o1, o2 = 0, 0
	for i = 1,8 do
		local t1, t2 = loop[i]:run(i1)
		o1 = o1 + t1
		o2 = o2 + t2
	end
	return o1, o2
end)


jack:midi("midi", function(channel, t, d1, d2)

	if t == "noteon" or t == "noteoff" then
		local onoff = t == "noteon"
		local note = d1
		if note >= 48 then
			local i = note - 47
			loop[i].rec = onoff
			print("REC", i, onoff)
		elseif note >= 44 then
			local i = note - 43 
			print("CLEAR", i)
			if onoff then
				for j = 1, #loop[i].buf do
					loop[i].buf[j] = 0
				end
			end
		end
	end

	if t == "cc" then
		local v = d2 / 127
		if d1 > 4 then
			loop[d1-4].pan = v * 2 - 1
		else
			loop[d1].vol = v
		end
	end
end)

jack:connect("worp")

-- vi: ft=lua ts=3 sw=3

