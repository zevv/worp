
local Dsp = {}

srate = 44100



function Dsp:mkgen(t, init)

	local gen = {}

	setmetatable(gen, {
		__call = function(_, ...)
			return t.fn_gen(gen, ...)
		end,
		__index = {
			set = function(_, vs)
				for k, v in pairs(vs) do gen[k] = v end
				return t.fn_set(gen)
			end,
			info = function()
				return t
			end,
			get = function()
				return gen
			end
		}
	})

	init = init or {}
	for _, arg in ipairs(t.args) do
		gen[arg.name] = init[arg.name] or arg.default
	end

	gen:set(arg)

	return gen
end

function Dsp:delay(t)
	local s = t * 44100
	local head = 1
	local buf = {}
	return function(v)
		buf[head] = v
		head = (head % s) + 1
		return buf[head] or 0
	end
end

				
-- http://www.taygeta.com/random/gaussian.html

function Dsp:noise(init)

	local random, sqrt, log = math.random, math.sqrt, math.log
	local type, y1, y2
	
	local function rand()
		return 2 * random() - 1
	end
	
	return Dsp:mkgen({
		name = "noise",
		description = "Noise generator",
		args = {
			{
				name = "type",
				description = "Noise type",
				range = "uniform,gaussian",
				default = "uniform",
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

		fn_set = function(arg)
			type = arg.type
		end,
	}, init)

end


function Dsp:diode(_)
	return function(v)
		return v > 0 and v or -v
	end
end


function Dsp:osc(init)

	local sin = math.sin
	local i, di = 0, 0

	return Dsp:mkgen({
		name = "osc",
		description = "Sine oscillator",
		args = {
			{
				name = "f",
				description = "Frequency",
				range = "0..20000",
				log = true,
				unit = "Hz",
				default = 440,
			},
		},
		fn_set = function(arg)
			di = arg.f * math.pi * 2 / srate 
		end,
		fn_gen = function()
			i = i + di
			return sin(i)
		end
	}, init)
end


function Dsp:saw(init)

	local v, dv = 0, 0

	return Dsp:mkgen({
		name = "saw",
		description = "Saw tooth oscillator",
		args = {
			{
				name = "f",
				description = "Frequency",
				range = "0..20000",
				log = true,
				unit = "Hz",
				default = 440,
			},
		},
		fn_set = function(arg)
			dv = 2 * arg.f / srate
		end,
		fn_gen = function()
			v = v + dv
			if v > 1 then v = v - 2 end
			return v
		end
	}, init)

end



function Dsp:adsr(init)

	local arg = {
		A = 0,
		D = 0,
		S = 1,
		R = 0,
		on = true,
	}

	local state, v = nil, 0
	local dv_A, dv_D, dv_R = 0, 0, 0
	local dv = {}

	return Dsp:mkgen({
		name = "adsr",
		description = "ADSR envelope generator",
		args = {
			{
				name = "on",
				description = "State",
				range = "true,false",
				default = "true",
			}, {
				name = "A",
				description = "Attack",
				range = "0..10",
				unit = "sec",
				default = "0",
			}, {
				name = "D",
				description = "Decay",
				range = "0..10",
				unit = "sec",
				default = "0",
			}, {
				name = "S",
				description = "Sustain",
				range = "0..1",
				default = "1",
			}, {
				name = "R",
				description = "Release",
				range = "0..10",
				unit = "sec",
				default = "0",
			}, 
		},
		fn_gen = function(arg)
			if arg.on then
				if state == nil then
					state, dv = "A", dv_A
				elseif state == "A" and v >= 1 then
					state, dv = "D", dv_D
				elseif state == "D" and v < arg.S then
					state, dv = "S", 0
				end
			else
				if state == "R" and v <= 0 then
					state, dv = "done", 0
				else
					state, dv = "R", dv_R
				end
			end
			v = v + dv
			v = math.max(v, 0)
			v = math.min(v, 1)
			return v
		end,

		fn_set = function(arg)
			dv_A =  1/(srate * arg.A)
			dv_D = -1/(srate * arg.D)
			dv_R = -1/(srate * arg.R)
		end
	}, init)
end


		
-- Biquads, based on http://www.musicdsp.org/files/Audio-EQ-Cookbook.txt

function Dsp:filter(init)
	
	local fs = 44100
	local a0, a1, a2, b0, b1, b2
	local x0, x1, x2 = 0, 0, 0
	local y0, y1, y2 = 0, 0, 0

	return Dsp:mkgen({
		name = "filter",
		description = "Biquad multi-mode filter",
		args = {
			{
				name = "type",
				description = "Filter type",
				range = "lp,hp,bp,bs,ls,hs,eq",
				default = "lp",
			}, {
				name = "f",
				description = "Frequency",
				range = "0..20000",
				log = true,
				unit = "Hz",
				default = 440,
			}, {
				name = "Q",
				description = "Resonance",
				range = "0.1..100",
				default = 1,
			}, {
				name = "gain",
				description = "Shelf filter gain",
				range = "-60..60",
				unit = "dB",
				default = 0
			}
		},

		fn_set = function(gen)
			local w0 = 2 * math.pi * (gen.f / fs)
			local alpha = math.sin(w0) / (2*gen.Q)
			local cos_w0 = math.cos(w0)
			local A = math.pow(10, gen.gain/40)

			if gen.type == "hp" then
				b0, b1, b2 = (1 + cos_w0)/2, -(1 + cos_w0), (1 + cos_w0)/2
				a0, a1, a2 = 1 + alpha, -2*cos_w0, 1 - alpha

			elseif gen.type == "lp" then
				b0, b1, b2 = (1 - cos_w0)/2, 1 - cos_w0, (1 - cos_w0)/2
				a0, a1, a2 = 1 + alpha, -2*cos_w0, 1 - alpha

			elseif gen.type == "bp" then
				b0, b1, b2 = gen.Q*alpha, 0, -gen.Q*alpha
				a0, a1, a2 = 1 + alpha, -2*cos_w0, 1 - alpha

			elseif gen.type == "bs" then
				b0, b1, b2 = 1, -2*cos_w0, 1
				a0, a1, a2 = 1 + alpha, -2*cos_w0, 1 - alpha

			elseif gen.type == "ls" then
				local ap1, am1, tsAa = A+1, A-1, 2 * math.sqrt(A) * alpha
				local am1_cos_w0, ap1_cos_w0 = am1 * cos_w0, ap1 * cos_w0
				b0, b1, b2 = A*( ap1 - am1_cos_w0 + tsAa ), 2*A*( am1 - ap1_cos_w0 ), A*( ap1 - am1_cos_w0 - tsAa )
				a0, a1, a2 = ap1 + am1_cos_w0 + tsAa, -2*( am1 + ap1_cos_w0 ), ap1 + am1_cos_w0 - tsAa

			elseif gen.type == "hs" then
				local ap1, am1, tsAa = A+1, A-1, 2 * math.sqrt(A) * alpha
				local am1_cos_w0, ap1_cos_w0 = am1 * cos_w0, ap1 * cos_w0
				b0, b1, b2 = A*( ap1 + am1_cos_w0 + tsAa ), -2*A*( am1 + ap1_cos_w0 ), A*( ap1 + am1_cos_w0 - tsAa )
				a0, a1, a2 = ap1 - am1_cos_w0 + tsAa, 2*( am1 - ap1_cos_w0 ), ap1 - am1_cos_w0 - tsAa

			elseif gen.type == "eq" then
				b0, b1, b2 = 1 + alpha*A, -2*cos_w0, 1 - alpha*A
				a0, a1, a2 = 1 + alpha/A, -2*cos_w0, 1 - alpha/A

			elseif gen.type == "ap" then
				b0, b1, b2 = 1 - alpha, -2*cos_w0, 1 + alpha
				a0, a1, a2 = 1 + alpha, -2*cos_w0, 1 - alpha

			else
				error("Unsupported filter type " .. type)
			end
		end,

		fn_gen = function(arg, x0)
			y2, y1 = y1, y0
			y0 = (b0 / a0) * x0 + (b1 / a0) * x1 + (b2 / a0) * x2 - (a1 / a0) * y1 - (a2 / a0) * y2
			x2, x1 = x1, x0
			return y0
		end
	}, init)

end

		
-- based on Jezar's public domain C++ sources,

function Dsp:reverb(init)

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

	local function fcomb(bufsize, feedback, damp)
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

	local comb, allp
	local gain
	local dry, wet1, wet2

	return Dsp:mkgen({
		name = "reverb",
		description = "Freeverb reverb",
		args = {
			{
				name = "wet",
				description = "Wet volume",
				range = "0..1",
				default = "0.5",
			}, {
				name = "dry",
				description = "Dry volume",
				range = "0..1",
				default = "0.5",
			}, {
				name = "room",
				description = "Room size",
				range = "0..1.1",
				default = "0.5",
			}, {
				name = "damp",
				description = "Damping",
				range = "0..1",
				default = "0.5",
			}
		},
		fn_set = function(arg)
			local initialroom = arg.room 
			local initialdamp = arg.damp 
			local initialwet = arg.wet/scalewet
			local initialdry = arg.dry or 0
			local initialwidth = 2
			local initialmode = 0
			local stereospread = 23

			local wet = initialwet * scalewet
			local roomsize = (initialroom*scaleroom) + offsetroom
			dry = initialdry * scaledry
			local damp = initialdamp * scaledamp
			local width = initialwidth
			local mode = initialmode

			wet1 = wet*(width/2 + 0.5)
			wet2 = wet*((1-width)/2)

			local roomsize1 = roomsize
			local damp1 = damp
			gain = fixedgain

			comb, allp = { 
				{
					fcomb(1116, roomsize1, damp1), fcomb(1188, roomsize1, damp1), 
					fcomb(1277, roomsize1, damp1), fcomb(1356, roomsize1, damp1),
					fcomb(1422, roomsize1, damp1), fcomb(1491, roomsize1, damp1), 
					fcomb(1557, roomsize1, damp1), fcomb(1617, roomsize1, damp1),
				}, {
					fcomb(1116+stereospread, roomsize1, damp1), fcomb(1188+stereospread, roomsize1, damp1),
					fcomb(1277+stereospread, roomsize1, damp1), fcomb(1356+stereospread, roomsize1, damp1),
					fcomb(1422+stereospread, roomsize1, damp1), fcomb(1491+stereospread, roomsize1, damp1),
					fcomb(1557+stereospread, roomsize1, damp1), fcomb(1617+stereospread, roomsize1, damp1),
				}
			}, {
				{ 
					allpass(556), allpass(441), allpass(341), allpass(225), 
				}, { 
					allpass(556+stereospread), allpass(441+stereospread), 
					allpass(341+stereospread), allpass(225+stereospread), 
				}
			}
		end,
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


--
-- Make polyphonic synth. Takes sound generator function, and 
-- returns an instrument function and dsp function
--

function Dsp:poly(fn_gen, max)

	local vs = {}
	local nvs = 0

	local fn_note = function(onoff, note, vel)
		local freq = 440 * math.pow(2, (note-57) / 12)
		if onoff then
			if max and nvs >= max then
				local t_oldest, v_oldest = time(), nil
				for v in pairs(vs) do
					if v.t < t_oldest then
						v_oldest, t_oldest = v, t_oldest
					end
				end
				vs[v_oldest] = nil
				nvs = nvs - 1
			end
			local v = {
				t = time(),
				note = note,
				fn = fn_gen(freq, vel)
			}
			vs[v] = true
			nvs = nvs + 1
		else
			for v in pairs(vs) do
				if v.note == note then
					v.fn("stop")
				end
			end
		end
	end

	local fn_dsp = function()
		local o = 0
		for v in pairs(vs) do
			local p = v.fn()
			if p then
				o = o + p * 0.1
			else
				vs[v] = nil
				nvs = nvs - 1
			end
		end
		return o
	end

	return fn_note, fn_dsp
end



return Dsp

-- vi: ft=lua ts=3 sw=3
