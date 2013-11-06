
--
-- Make mod polyphonic
--

function Dsp:Poly(init)

	local count 
	local gen
	local vs = {}
	local gain
	local freq, vel = 0, 0

	local mod = Dsp:Mod({
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


-- vi: ft=lua ts=3 sw=3
