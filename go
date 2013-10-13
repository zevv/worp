#!/usr/bin/luajit

package.path = package.path .. ";./lib/?.lua"
package.cpath = package.cpath .. ";./lib/?.so"
require "strict"

p = require "posix"

env = setmetatable({}, { __index = _G })
local ev_queue = {}
local t_start = nil
local fds = {}

t_now = 0

-- 
-- Internal functions
--

function safecall(fn, ...)
	local function errhandler(err)
		local errmsg = debug.traceback("Error: " .. err, 3)
		print(errmsg)
		return errmsg
	end
	return xpcall(fn, errhandler, ...)
end


function time()
	local s, ns = p.clock_gettime(p.CLOCK_MONOTONIC)
	local t = s + ns / 1e9
	t_start = t_start or t
	return t - t_start
end


local function load_code(code)
	local fn, err = loadstring(code, "chunk")
	if fn then
		setfenv(fn, env)
		t_now = time()
		return safecall(fn)
	else
		return false, err
	end
end


--
-- Schedule function 'fn' to be called at time 't'. 'fn' can be as string,
-- which will be resolved at calling time
--

function at(t, fn, ...)
	local ev = {
		t_when = t_now + t,
		fn = fn,
		args = { ... }
	}
	table.insert(ev_queue, ev)
	table.sort(ev_queue, function(a, b)
		return a.t_when > b.t_when
	end)
end


--
-- Clear all events from the event queue and mute synth
--

function stop()
	ev_queue = {}
end


--
-- Play a note using the given sound generator
--

function play(fn, note, vol, dur)
	fn(true, note, vol or 127)
	at(dur * 0.99, function()
		fn(false, note, vol)
	end)
end


function watch_fd(fd, fn)
	fds[fd] = { events = { IN = true }, fn = fn }
end


-- 
-- Main event loop
--

math.randomseed(os.time())


local s = p.socket(p.AF_INET, p.SOCK_DGRAM, 0)
p.bind(s, { family = p.AF_INET, port = 9889, addr = "0.0.0.0" })

watch_fd(s, function()
	local code = p.recv(s, 65535)
	local ok, err = load_code(code)
	print(ok, err)
end)

local t = 0

p.signal(p.SIGINT, os.exit)

print("Ready")


if arg[1] then
	load_code(io.open(arg[1]):read("*a"))
end

local t_start = time()
t_now = 0

while true do

	local dt = 10
	local ev = ev_queue[#ev_queue]

	if ev then
		dt = math.min(ev.t_when - time())
	end

	if dt > 0 then
		local r, a = p.poll(fds, dt * 1000)
		if r and r > 0 then

			for fd in pairs(fds) do
				if fds[fd].revents and fds[fd].revents.IN then
					fds[fd].fn()
				end
			end
		end
	end

	while ev and time() > ev.t_when do
		table.remove(ev_queue)
		t_now = ev.t_when
		safecall(ev.fn, unpack(ev.args))
		ev = ev_queue[#ev_queue]
	end

end

-- vi: ft=lua ts=3 sw=3
