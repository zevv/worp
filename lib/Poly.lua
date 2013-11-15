
--
-- The Poly function provides an easy way to create polyphonic instruments.
--

function Poly(mkinstr, count)
	
	count = count or 5

	local vs = {}
	for i = 1, count do
		local vi, vg = mkinstr()
		vs[i] = { instr = vi, gen = vg, free = true, age = time() }
	end

	local function instr(note, vel)
		if vel > 0 then
			for i, v in pairs(vs) do
				if v.free then
					v.note = note
					v.instr(note, vel)
					v.free = false
					break
				end
			end
		else
			for i, v in pairs(vs) do
				if v.note == note then
					v.instr(note, 0)
					v.free = true
					v.age = time()
				end
				table.sort(vs, function(a, b) return a.age < b.age end)
			end
		end
	end

	local function gen(note, vel)
		local o1, o2 = 0, 0
		for _, v in ipairs(vs) do
			local i1, i2 = v.gen()
			o1 = o1 + (i1 or 0)
			o2 = o2 + (i2 or 0)
		end
		return o1, o2
	end

	return instr, gen
end

-- vi: ft=lua ts=3 sw=3

