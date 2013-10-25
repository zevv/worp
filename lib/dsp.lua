
srate = 44100

return {

	delay = function(s)
		s = s * 44100
		local head = 1
		local buf = {}
		return function(v)
			buf[head] = v
			head = (head % s) + 1
			return buf[head] or 0
		end
	end,


	noise = function()
		return math.random
	end,


	osc = function(freq)
		local cos = math.cos
		local i, di = 0, 0
		local fn = function(cmd, v)
			if cmd == "f" then
				di = math.pi * 2 * v/srate 
				return
			end
			i = i + di
			return cos(i)
		end
		fn(freq)
		return fn
	end,


	saw = function(freq)
		local v, dv = 0, 0
		local fn = function(cmd, val)
			if cmd == "f" then
				dv = val/srate
			end
			v = v + dv
			if v > 1 then v = v - 1 end
			return v
		end
		fn("f", freq)
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

		
	-- Biquads, based on http://www.musicdsp.org/files/Audio-EQ-Cookbook.txt

	filter = function(ft, f0, Q, gain)

		local fs = 44100
		local ft = ft or "lp"
		local f0 = f0 or 1000
		local gain = gain or 0
		local Q = Q or 1
		local a0, a1, a2, b0, b1, b2
		local x0, x1, x2 = 0, 0, 0
		local y0, y1, y2 = 0, 0, 0

		local function calc()

			local w0 = 2 * math.pi * (f0 / fs)
			local alpha = math.sin(w0) / (2*Q)
			local cos_w0 = math.cos(w0)
			local A = math.pow(10, gain/40)

			-- High pass
			
			if ft == "hp" then
				b0, b1, b2 = (1 + cos_w0)/2, -(1 + cos_w0), (1 + cos_w0)/2
				a0, a1, a2 = 1 + alpha, -2*cos_w0, 1 - alpha

			-- Low pass

			elseif ft == "lp" then
				b0, b1, b2 = (1 - cos_w0)/2, 1 - cos_w0, (1 - cos_w0)/2
				a0, a1, a2 = 1 + alpha, -2*cos_w0, 1 - alpha

			-- Band pass

			elseif ft == "bp" then
				b0, b1, b2 = Q*alpha, 0, -Q*alpha
				a0, a1, a2 = 1 + alpha, -2*cos_w0, 1 - alpha

			-- Band stop

			elseif ft == "bs" then
				b0, b1, b2 = 1, -2*cos_w0, 1
				a0, a1, a2 = 1 + alpha, -2*cos_w0, 1 - alpha

			-- Low shelf

			elseif ft == "ls" then
				local ap1, am1, tsAa = A+1, A-1, 2 * math.sqrt(A) * alpha
				local am1_cos_w0, ap1_cos_w0 = am1 * cos_w0, ap1 * cos_w0
				b0, b1, b2 = A*( ap1 - am1_cos_w0 + tsAa ), 2*A*( am1 - ap1_cos_w0 ), A*( ap1 - am1_cos_w0 - tsAa )
				a0, a1, a2 = ap1 + am1_cos_w0 + tsAa, -2*( am1 + ap1_cos_w0 ), ap1 + am1_cos_w0 - tsAa

			-- High shelf

			elseif ft == "hs" then
				local ap1, am1, tsAa = A+1, A-1, 2 * math.sqrt(A) * alpha
				local am1_cos_w0, ap1_cos_w0 = am1 * cos_w0, ap1 * cos_w0
				b0, b1, b2 = A*( ap1 + am1_cos_w0 + tsAa ), -2*A*( am1 + ap1_cos_w0 ), A*( ap1 + am1_cos_w0 - tsAa )
				a0, a1, a2 = ap1 - am1_cos_w0 + tsAa, 2*( am1 - ap1_cos_w0 ), ap1 - am1_cos_w0 - tsAa

			-- Peaking EQ

			elseif ft == "eq" then
				b0, b1, b2 = 1 + alpha*A, -2*cos_w0, 1 - alpha*A
				a0, a1, a2 = 1 + alpha/A, -2*cos_w0, 1 - alpha/A

			-- All pass

			elseif ft == "ap" then
				b0, b1, b2 = 1 - alpha, -2*cos_w0, 1 + alpha
				a0, a1, a2 = 1 + alpha, -2*cos_w0, 1 - alpha

			else
				error("Unsupported filter type " .. ft)
			end
		end

		calc()

		return function(x0, arg)

			if type(x0) == "string" then
				if x0 == "ft" then ft = arg end
				if x0 == "f0" then f0 = arg end
				if x0 == "Q" then Q = arg end
				if x0 == "gain" then gain = arg end
				return calc()
			end

			y2, y1 = y1, y0
			y0 = (b0 / a0) * x0 + (b1 / a0) * x1 + (b2 / a0) * x2 - (a1 / a0) * y1 - (a2 / a0) * y2
			x2, x1 = x1, x0

			return y0

		end
	
	end,

		
	-- based on Jezar's public domain C++ sources,

	reverb = function(wet, dry, room, damp)

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

		local function comb(bufsize, feedback, damp)
			local buffer = {}
			local bufidx = 0
			local damp1 = damp
			local damp2 = 1 - damp
			local filterstore = 0
			return function(input)
				local output = buffer[bufidx] or 0
				local filterstore = (output*damp2) + (filterstore*damp1)
				buffer[bufidx] = input + (filterstore*feedback)
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
		local initialroom = room or 0.5
		local initialdamp = damp or 0.5
		local initialwet = (wet or 1)/scalewet
		local initialdry = dry or 0
		local initialwidth = 2
		local initialmode = 0
		local stereospread = 23

		local wet = initialwet * scalewet
		local roomsize = (initialroom*scaleroom) + offsetroom
		local dry = initialdry * scaledry
		local damp = initialdamp * scaledamp
		local width = initialwidth
		local mode = initialmode

		local wet1 = wet*(width/2 + 0.5)
		local wet2 = wet*((1-width)/2)

		local roomsize1 = roomsize
		local damp1 = damp
		local gain = fixedgain

		local comb, allp = { 
			{
				comb(1116, roomsize1, damp1), comb(1188, roomsize1, damp1), 
				comb(1277, roomsize1, damp1), comb(1356, roomsize1, damp1),
				comb(1422, roomsize1, damp1), comb(1491, roomsize1, damp1), 
				comb(1557, roomsize1, damp1), comb(1617, roomsize1, damp1),
			}, {
				comb(1116+stereospread, roomsize1, damp1), comb(1188+stereospread, roomsize1, damp1),
				comb(1277+stereospread, roomsize1, damp1), comb(1356+stereospread, roomsize1, damp1),
				comb(1422+stereospread, roomsize1, damp1), comb(1491+stereospread, roomsize1, damp1),
				comb(1557+stereospread, roomsize1, damp1), comb(1617+stereospread, roomsize1, damp1),
			}
		}, {
			{ 
				allpass(556), allpass(441), allpass(341), allpass(225), 
			}, { 
				allpass(556+stereospread), allpass(441+stereospread), 
				allpass(341+stereospread), allpass(225+stereospread), 
			}
		}

		return function(in1, in2)
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

	end,

	-- Make polyphonic synth. Takes sound generator function, and 
	-- returns an instrument function and dsp function

	poly = function(fn_gen)

		local vs = {}

		local fn_note = function(onoff, note, vel)
			local f = 440 * math.pow(2, (note-57) / 12)
			local v = vel / 127

			if onoff then
				vs[note] = fn_gen(f, v)
			else
				vs[note]("stop")
			end
		end

		local fn_dsp = function()
			local o = 0
			for note, v in pairs(vs) do
				local p = v()
				if p then
					o = o + p * 0.1
				else
					vs[note] = nil
				end
			end
			return o
		end

		return fn_note, fn_dsp
	end,

}


-- vi: ft=lua ts=3 sw=3
