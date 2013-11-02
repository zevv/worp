
local Dsp = {}

srate = 44100



function Dsp:mkgen(t, init)

	local gen = {}
	local set_cb = {}

	local controls = t.controls
	controls.fn_set = controls.fn_set or function() end

	for _, control in ipairs(controls) do
		controls[control.id] = control
		control.fn_set = control.fn_set or function() end
	end

	local function control_set(id, value)
		local control = controls[id]
		control.fn_set(value)
		for fn in pairs(set_cb[id] or {}) do
			fn(value)
		end
	end

	setmetatable(gen, {
		__call = function(_, ...)
			return t.fn_gen(gen, ...)
		end,
		__index = {
			set = function(_, id, value)
				if type(id) == "table" then
					for id, value in pairs(id) do
						control_set(id, value)
					end
				else
					control_set(id, value)
				end
				controls.fn_set()
			end,
			on_set = function(_, id, fn)
				set_cb[id] = set_cb[id] or {}
				set_cb[id][fn] = true
			end,
			info = function()
				return t
			end,
			get = function()
				return gen
			end
		}
	})

	local init = init or {}
	local val = {}
	for _, arg in ipairs(t.controls) do
		val[arg.id] = init[arg.id] or arg.default
	end

	gen:set(val)

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
		id = "noise",
		description = "Noise generator",
		controls = {
			{
				id = "type",
				description = "Noise type",
				range = "uniform,gaussian",
				default = "uniform",
				fn_set = function(val) type = val end
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
		id = "osc",
		description = "Sine oscillator",
		controls = {
			{
				id = "f",
				description = "Frequency",
				range = "0..20000",
				log = true,
				unit = "Hz",
				default = 440,
				fn_set = function(val)
					di = val * math.pi * 2 / srate 
				end
			},
		},
		fn_gen = function()
			i = i + di
			return sin(i)
		end
	}, init)
end


function Dsp:saw(init)

	local v, dv = 0, 0

	return Dsp:mkgen({
		id = "saw",
		description = "Saw tooth oscillator",
		controls = {
			{
				id = "f",
				description = "Frequency",
				range = "0..20000",
				log = true,
				unit = "Hz",
				default = 440,
				fn_set = function(val)
					dv = 2 * val / srate
				end,
			},
		},
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
	local dv_A, dv_D, dv_R, level_S = 0, 0, 0, 1
	local dv = {}

	return Dsp:mkgen({
		id = "adsr",
		description = "ADSR envelope generator",
		controls = {
			{
				id = "on",
				description = "State",
				range = "true,false",
				default = "true",
				fn_set = function(val)
					if val and  state == nil then
						state, dv = "A", dv_A
					end
					if not val then
						if state == "R" and v <= 0 then
							state, dv = "done", 0
						else
							state, dv = "R", dv_R
						end
					end
				end
			}, {
				id = "A",
				description = "Attack",
				range = "0..10",
				unit = "sec",
				default = "0",
				fn_set = function(val)
					dv_A =  1/(srate * val)
				end,
			}, {
				id = "D",
				description = "Decay",
				range = "0..10",
				unit = "sec",
				default = "0",
				fn_set = function(val)
					dv_D = -1/(srate * arg.D)
				end,
			}, {
				id = "S",
				description = "Sustain",
				range = "0..1",
				default = "1",
				fn_set = function(val)
					level_S = val
				end
			}, {
				id = "R",
				description = "Release",
				range = "0..10",
				unit = "sec",
				default = "0",
				fn_set = function(val)
					dv_R = -1/(srate * val)
				end
			}, 
		},
		fn_gen = function(arg)
			if state == "A" and v >= 1 then
				state, dv = "D", dv_D
			elseif state == "D" and v < level_S then
				state, dv = "S", 0
			end
			v = v + dv
			v = math.max(v, 0)
			v = math.min(v, 1)
			return v
		end,

	}, init)
end


		
-- Biquads, based on http://www.musicdsp.org/files/Audio-EQ-Cookbook.txt

function Dsp:filter(init)
	
	local fs = 44100
	local a0, a1, a2, b0, b1, b2
	local x0, x1, x2 = 0, 0, 0
	local y0, y1, y2 = 0, 0, 0

	local type, f, Q, gain

	return Dsp:mkgen({
		id = "filter",
		description = "Biquad multi-mode filter",
		controls = {
			fn_set = function()
				local w0 = 2 * math.pi * (f / fs)
				local alpha = math.sin(w0) / (2*Q)
				local cos_w0 = math.cos(w0)
				local A = math.pow(10, gain/40)

				if type == "hp" then
					b0, b1, b2 = (1 + cos_w0)/2, -(1 + cos_w0), (1 + cos_w0)/2
					a0, a1, a2 = 1 + alpha, -2*cos_w0, 1 - alpha

				elseif type == "lp" then
					b0, b1, b2 = (1 - cos_w0)/2, 1 - cos_w0, (1 - cos_w0)/2
					a0, a1, a2 = 1 + alpha, -2*cos_w0, 1 - alpha

				elseif type == "bp" then
					b0, b1, b2 = Q*alpha, 0, -Q*alpha
					a0, a1, a2 = 1 + alpha, -2*cos_w0, 1 - alpha

				elseif type == "bs" then
					b0, b1, b2 = 1, -2*cos_w0, 1
					a0, a1, a2 = 1 + alpha, -2*cos_w0, 1 - alpha

				elseif type == "ls" then
					local ap1, am1, tsAa = A+1, A-1, 2 * math.sqrt(A) * alpha
					local am1_cos_w0, ap1_cos_w0 = am1 * cos_w0, ap1 * cos_w0
					b0, b1, b2 = A*( ap1 - am1_cos_w0 + tsAa ), 2*A*( am1 - ap1_cos_w0 ), A*( ap1 - am1_cos_w0 - tsAa )
					a0, a1, a2 = ap1 + am1_cos_w0 + tsAa, -2*( am1 + ap1_cos_w0 ), ap1 + am1_cos_w0 - tsAa

				elseif type == "hs" then
					local ap1, am1, tsAa = A+1, A-1, 2 * math.sqrt(A) * alpha
					local am1_cos_w0, ap1_cos_w0 = am1 * cos_w0, ap1 * cos_w0
					b0, b1, b2 = A*( ap1 + am1_cos_w0 + tsAa ), -2*A*( am1 + ap1_cos_w0 ), A*( ap1 + am1_cos_w0 - tsAa )
					a0, a1, a2 = ap1 - am1_cos_w0 + tsAa, 2*( am1 - ap1_cos_w0 ), ap1 - am1_cos_w0 - tsAa

				elseif type == "eq" then
					b0, b1, b2 = 1 + alpha*A, -2*cos_w0, 1 - alpha*A
					a0, a1, a2 = 1 + alpha/A, -2*cos_w0, 1 - alpha/A

				elseif type == "ap" then
					b0, b1, b2 = 1 - alpha, -2*cos_w0, 1 + alpha
					a0, a1, a2 = 1 + alpha, -2*cos_w0, 1 - alpha

				else
					error("Unsupported filter type " .. type)
				end
			end,
			{
				id = "type",
				description = "Filter type",
				range = "lp,hp,bp,bs,ls,hs,eq",
				default = "lp",
				fn_set = function(val) type = val end
			}, {
				id = "f",
				description = "Frequency",
				range = "0..20000",
				log = true,
				unit = "Hz",
				default = 440,
				fn_set = function(val) f = val end
			}, {
				id = "Q",
				description = "Resonance",
				range = "0.1..100",
				default = 1,
				fn_set = function(val) Q = val end
			}, {
				id = "gain",
				description = "Shelf/EQ filter gain",
				range = "-60..60",
				unit = "dB",
				default = 0,
				fn_set = function(val) gain = val end
			}
		},

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

	return Dsp:mkgen({
		id = "reverb",
		description = "Freeverb reverb",
		controls = {
			fn_set = function()
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
				range = "0..1",
				default = "0.5",
				fn_set = function(val) arg_wet = val end
			}, {
				id = "dry",
				description = "Dry volume",
				range = "0..1",
				default = "0.5",
				fn_set = function(val) arg_dry = val end
			}, {
				id = "room",
				description = "Room size",
				range = "0..1.1",
				default = "0.5",
				fn_set = function(val) arg_room = val end
			}, {
				id = "damp",
				description = "Damping",
				range = "0..1",
				default = "0.5",
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
