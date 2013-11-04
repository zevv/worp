
local Dsp = {}

srate = 44100

function Dsp:mkcontrol(def, mod)

	local control = {

		-- methods

		get = function(control)
			return control.value
		end,
		
		set = function(control, value, update)
			if control.type == "enum" and type(value) == "number" then
				value = control.options[math.floor(value + 0.5)]
			end
			if value then
				control.value = value
				for fn in pairs(control.fn_set) do
					fn(value)
				end
				if update ~= false then
					mod:update()
				end
			end
		end,

		set_uni = function(control, v, update)
			if control.min and control.max then
				v = control.min + v * (control.max-control.min)
				if control.log then v = (control.max+1) ^ (v/control.max) - 1 end
				control:set(v)
			end
		end,

		on_set = function(control, fn)
			control.fn_set[fn] = true
		end,

		-- data
	
		id = def.id or "",
		description = def.description or "",
		type = def.type or "number",
		fmt = def.fmt,
		min = def.min or 0,
		max = def.max or 1,
		options = def.options or {},
		log = def.log,
		unit = def.unit,
		default = def.default,
		value = nil,
		fn_set = {},
	}

	if def.type == "enum" then
		control.min, control.max = 1, #def.options
	end

	setmetatable(control, {
		__tostring = function()
			return "Control:%s:%s(%s)" % { mod.id, control.id, control.value }
		end
	})

	if def.fn_set then
		control:on_set(def.fn_set)
	end
	control:set(def.default, false)

	return control

end


function Dsp:mkmod(def, init)

	local mod = {

		-- methods
		
		update = function(mod)
			if def.controls.fn_update then
				def.controls.fn_update()
			end
		end,

		set = function(mod, id, value)
			if type(id) == "table" then
				for id, value in pairs(id) do
					mod:control(id):set(value, false)
				end
				mod:update()
			else
				mod:control(id):set(value)
			end
		end,

		controls = function(mod)
			return mod.control_list
		end,

		get = function(mod)
			return mod
		end,

		control = function(mod, id)
			return mod.control_list[id]
		end,

		help = function(mod)
			print("%s: %s" % { mod.id, mod.description })
			for _, control in ipairs(mod:controls()) do
				print(" - %s: %s (%s)" % { control.id, control.description, control.unit or "" })
			end
		end,

		-- data

		id = def.id,
		description = def.description,
		control_list = {}
	}
	
	setmetatable(mod, {
		__tostring = function()
			return "Generator:%s" % { def.id }
		end,
		__call = function(_, ...)
			return def.fn_gen(mod, ...)
		end,
	})

	for i, def in ipairs(def.controls) do
		local control = Dsp:mkcontrol(def, mod)
		mod.control_list[i] = control
		mod.control_list[control.id] = control
		if init then
			control:set(init[control.id], false)
		end
	end

	mod:update()

	return mod
end


function Dsp:const(init)

	local c

	return Dsp:mkmod({
		id = "const",
		description = "Constant value",
		controls = {
			{
				id = "c",
				description = "Value",
				default = 1,
				fmt = "%0.2f",
				fn_set = function(val) c = val end,
			},
		},

		fn_gen = function()
			return c
		end

	}, init)

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
	
	return Dsp:mkmod({
		id = "noise",
		description = "Noise generator",
		controls = {
			{
				id = "type",
				description = "Noise type",
				type = "enum",
				options = "uniform,gaussian",
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

	return Dsp:mkmod({
		id = "osc",
		description = "Sine oscillator",
		controls = {
			{
				id = "f",
				description = "Frequency",
				max = 20000,
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

	return Dsp:mkmod({
		id = "saw",
		description = "Saw tooth oscillator",
		controls = {
			{
				id = "f",
				description = "Frequency",
				max = 20000,
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
	local velocity = 0
	local dv_A, dv_D, dv_R, level_S = 0, 0, 0, 1
	local dv = 0

	return Dsp:mkmod({
		id = "adsr",
		description = "ADSR envelope generator",
		controls = {
			{
				id = "vel",
				description = "Velocity",
				fn_set = function(val)
					if val > 0 then
						velocity = val
						state, dv = "A", dv_A
					end
					if val == 0 then
						state, dv = "R", dv_R
					end
				end
			}, {
				id = "A",
				description = "Attack",
				max = 10,
				unit = "sec",
				default = "0",
				fn_set = function(val)
					dv_A =  math.min(1/(srate * val), 1)
				end,
			}, {
				id = "D",
				description = "Decay",
				max = 10,
				unit = "sec",
				default = "0",
				fn_set = function(val)
					dv_D = math.max(-1/(srate * val), -1)
				end,
			}, {
				id = "S",
				description = "Sustain",
				default = "1",
				fn_set = function(val)
					level_S = val
				end
			}, {
				id = "R",
				description = "Release",
				max = 10,
				unit = "sec",
				default = "0",
				fn_set = function(val)
					dv_R = math.max(-1/(srate * val), -1)
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
			return v * velocity
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

	return Dsp:mkmod({
		id = "filter",
		description = "Biquad filter",
		controls = {
			fn_update = function()
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
				type = "enum",
				options =  { "lp", "hp", "bp", "bs", "ls", "hs", "eq", "ap" },
				default = "lp",
				fn_set = function(val) type = val end
			}, {
				id = "f",
				description = "Frequency",
				max = 20000,
				log = true,
				unit = "Hz",
				default = 440,
				fn_set = function(val) f = val end
			}, {
				id = "Q",
				description = "Resonance",
				min = 0.1,
				max = 100,
				default = 1,
				fn_set = function(val) Q = val end
			}, {
				id = "gain",
				description = "Shelf/EQ filter gain",
				min = -60,
				max = 60,
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

	return Dsp:mkmod({
		id = "reverb",
		description = "Reverb",
		controls = {
			fn_update = function()
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
				default = 0.5,
				fmt = "%0.2f",
				fn_set = function(val) arg_wet = val end
			}, {
				id = "dry",
				description = "Dry volume",
				default = 0.5,
				fmt = "%0.2f",
				fn_set = function(val) arg_dry = val end
			}, {
				id = "room",
				description = "Room size",
				max = 1.1,
				default = 0.5,
				fmt = "%0.2f",
				fn_set = function(val) arg_room = val end
			}, {
				id = "damp",
				description = "Damping",
				default = 0.5,
				fmt = "%0.2f",
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
-- Make mod polyphonic
--

function Dsp:poly(init)

	local count 
	local gen
	local vs = {}
	local gain
	local freq, vel = 0, 0

	local mod = Dsp:mkmod({
		id = "poly",
		description = "Polyphonic module",
		controls = {
			fn_update = function()

				if #vs ~= count then
					vs = {}
					for i = 1, count do
						vs[i] = { mod = gen(), free = true, age = time() }
					end
					gain = 1 / count
				end

				if vel > 0 then
					for i, v in pairs(vs) do
						if v.free then
							v.freq = freq
							v.mod:set { f = freq, vel = vel }
							v.free = false
							break
						end
					end
				else
					for i, v in pairs(vs) do
						if v.freq == freq then
							v.mod:set { vel = 0 }
							v.free = true
							v.age = time()
						end
						table.sort(vs, function(a, b) return a.age < b.age end)
					end
				end
			end,
			{
				id = "gen",
				type = "generator",
				description = "Generator module",
				fn_set = function(v) gen = v end
			}, {
				id = "f",
				description = "Frequency",
				max = 20000,
				log = true,
				unit = "Hz",
				default = 440,
				fn_set = function(v) freq = v end
			}, {
				id = "vel",
				description = "Velocity",
				fn_set = function(v) vel = v end
			}, {
				id = "count",
				description = "Voice count",
				default = 4,
				max = 10,
				fn_set = function(v) count = math.floor(v+0.5) end
			},
		},
		fn_gen = function()
			local o = 0
			for _, v in ipairs(vs) do
				o = o + v.mod()
			end
			return o * gain
		end
	}, init)

	local instr = function(note, vel)
		local freq = 440 * math.pow(2, (note-57) / 12)
		mod:set { f = freq, vel = vel }
	end

	return mod, instr

end


function Dsp:pitchshift(init)

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
	
	return Dsp:mkmod({
		id = "pitchshift",
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


return Dsp

-- vi: ft=lua ts=3 sw=3
