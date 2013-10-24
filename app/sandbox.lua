
--
-- Handle the sandbox for loading worp scripts.
--

local env = {}


--
-- Load and run the given lua source 
--

function sandbox_load(code, name)
	local fn, err = load(code, name, "t", env)
	if fn then
		local co = coroutine.create(fn)
		safecall(resumer(co))
	else
		print("Error: " .. fixup_error(err))
	end
end


function sandbox_init()

	-- Initialize env with default lua and worp libraries

	env.print = print
	env.dump = dump
	env.io = io
	env.os = os
	env.string = string
	env.table = table
	env.math = math
	env.pairs = pairs
	env.ipairs = ipairs
	env.at = at
	env.play = play
	env.time = time
	env.require = require

	env.Chord = require "chord"
	env.Linuxsampler = require "linuxsampler"
	env.Fluidsynth = require "fluidsynth"
	env.Jack = require "jack"
	env.Dsp = require "dsp"
	env.Chord = require "chord"
	env.Metro = require "metro"

	-- setmetatable(env, { __index = function(_, s) print(s) return _G[s] end})
	
	-- 
	-- Open an UDP socket to receive Lua code chunks, and register to the 
	-- mail loop.
	--

	local s = P.socket(P.AF_INET, P.SOCK_DGRAM, 0)
	P.bind(s, { family = P.AF_INET, port = 9889, addr = "127.0.0.1" })

	watch_fd(s, function()
		local code = P.recv(s, 65535)
		local from, to, name = 1, 1, "?"
		local f, t, n = code:match("\n%-%- live (%d+) (%d+) ([^\n]+)")
		if f then from, to, name = f, t, n end
		sandbox_load(code, "live " .. name .. ":" .. from)
	end)

end


function sandbox_get(name)
	return env[name]
end


-- vi: ft=lua ts=3 sw=3
