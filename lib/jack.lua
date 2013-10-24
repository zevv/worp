
local jack_c = require "jack_c"

--
-- Register jack audio ports, n_in input ports and n_out output ports.
-- Processing is done in given fn, all input data is given as arguments, all
-- returned data is passed as output data.
--

local function jack_dsp(jack, name, n_in, n_out, fn)

	local group = jack.group_list[name]

	if not group then

		group = {
			fn = fn,
			fn_ok = function() end
		}
		jack.group_list[name] = group

		local t = 0
		local dt = 1/jack.srate
		local gu, fd = jack_c.add_group(jack.j, name, n_in, n_out)

		-- This function gets called when the jack thread needs more data. The
		-- many calls into C should probably be optimized at some time

		watch_fd(fd, function()
			P.read(fd, 1)
			local ok = safecall(function()
				for i = 1, jack.bsize do
					jack_c.write(gu, group.fn(t, jack_c.read(gu)))
					t = t + dt
				end
			end)
			if not ok then
				print("Restoring last known good function")
				group.fn = group.fn_ok
			end
		end)

	else
		group.fn_ok = group.fn
		group.fn = fn
	end

end



--
-- Register jack midi port with given name. Received midi events are passed to
-- callback function
--

local function jack_midi(jack, name, fn)

	local midi_msg = {
		[0x90] = "noteon",
		[0x80] = "noteoff",
		[0xb0] = "cc",
		[0xc0] = "pc",
	}

	local fd = jack_c.add_midi(jack.j, name)

	watch_fd(fd, function()
		local msg = P.read(fd, 3)

		local b1, b2, b3 = string.byte(msg, 1, #msg)

		local t = bit.band(b1, 0xf0)
		t = midi_msg[t] or t
		local channel = bit.band(b1, 0x0f) + 1
		fn(channel, t, b2, b3)
		
	end)

end



local function jack_conn(jack, patt1, patt2)

	patt2 = patt2 or "*"
	logf(LG_DBG, "Connect %s -> %s", patt1, patt2)

	local function find(ps, patt)
		local l = {}
		for _, p in ipairs(ps) do
			local client = p.name:match("[^:]+")
			local dir = p.input and "input" or "output"
			if patt == '*' or p.name:find(patt, 1, true) then
				l[p.type] = l[p.type] or {}
				l[p.type][dir] = l[p.type][dir] or {}
				l[p.type][dir][client] = l[p.type][dir][client] or {}
				table.insert(l[p.type][dir][client], p)
			end
		end
		return l
	end
	
	-- Find all ports matching given patterns, index by type/direction/client
	
	local ps = jack_c.list_ports(jack.j)
	local l1 = find(ps, patt1)
	local l2 = find(ps, patt2)

	-- Iterate all types/directions/clients on patt1
	
	for t, ds in pairs(l1) do
		for d1, cs in pairs(ds) do
			for c1, ps1 in pairs(cs) do

				-- find and connect matching ports from patt2

				local d2 = (d1 == "input") and "output" or "input"
				if l2[t] and l2[t][d2] then
					for c2, ps2 in pairs(l2[t][d2]) do
						if c2 ~= c1 then
							for i = 1, math.max(#ps1, #ps2) do
								local p1 = ps1[math.min(i, #ps1)]
								local p2 = ps2[math.min(i, #ps2)]
								if p1.input then p1,p2 = p2,p1 end
								logf(LG_DBG, "  %s -> %s", p1.name, p2.name)
								jack_c.connect(jack.j, p1.name, p2.name)
							end
						end
					end
				end
			end
		end
	end
	
end


local function new(name, port_list, fn)
	
	local j, srate, bsize = jack_c.open(name or "worp")

	local jack = {

		-- methods

		dsp = jack_dsp,
		midi = jack_midi,
		connect = jack_conn,

		-- data
	
		j = j,
		srate = srate,
		bsize = bsize,
		group_list = {},

	}

	return jack

end


return {
   new = new
}

-- vi: ft=lua ts=3 sw=3

