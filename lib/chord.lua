
local chord_list = {

	-- triad chords
	
	[""] = { 0, 4, 7 }, -- major
	["-"] = { 0, 3, 7 }, -- minor
	["o" ] = { 0, 3, 6 }, -- diminshed
	["+"] = { 0, 3, 8 }, -- augmented

	-- four note chords
	
	["6"] = { 0, 4, 7, 9 }, -- major 6th
	["-6"] = { 0, 3, 7, 9 }, -- minor 6th
	["^7"] = { 0, 4, 7, 11 }, -- major 7th
	["7"] = { 0, 4, 7, 10 }, -- dominant 7th
	["-7"] = { 0, 3, 7, 10 }, -- minor 7th
	["-7b5"] = { 0, 3, 6, 9 }, -- minor 7th ♭5
	["o7"] = { 0, 3, 6, 8 }, -- diminished 7th
	["+7"] = { 0, 4, 6, 8 }, -- augmented 7th
}


local diatonic_list = {
	major = { 
		i = { 0, "" },
		i7 = { 0, "^7" },
		ii = { 2, "-" },
		ii7 = { 2, "-7" },
		iii = { 4, "-" },
		iii = { 4, "-7" },
		iv = { 5, "" },
		iv7 = { 5, "^7" },
		v = { 7, "" },
		v7 = { 7, "7" },
		vi = { 9, "-" },
		vi7 = { 9, "-7" },
		vii = { 11, "o" },
		vii7 = { 11, "o7" },
	},
	minor = {
		i = { 0, "-" },
		i7 = { 0, "-7" },
		ii = { 2, "o" },
		ii7 = { 2, "o7" },
		iii = { 3, "" },
		iii7 = { 3, "^7" },
		iv = { 5, "-" },
		iv7 = { 5, "-7" },
		v = { 7, "" },
		v7 = { 7, "7" },
		vi = { 8, "" },
		vi7 = { 8, "^7" },
		vii = { 11, "o" },
		vii7 = { 11, "o7" },
	}
}


local function new(_, base, type, degree)
	local ns = {}
	local i = diatonic_list[type][degree]
	for _, n in ipairs(chord_list[i[2]]) do
		ns[#ns+1] = base + i[1] + n
	end
	return ns
end



return {
	new = new
}

-- vi: ft=lua ts=3 sw=3

