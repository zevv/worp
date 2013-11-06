
t_now = 0

local evs = {}
local fds = {}
local t_start
local running = true

--
-- Schedule function 'fn' to be called in 't' seconds. 'fn' can be as string,
-- which will be resolved in the 'env' table at calling time
--

function at(t, fn, ...)
	local ev = {
		t_when = t_now + t,
		fn = fn,
		args = { ... }
	}
	table.insert(evs, ev)
	table.sort(evs, function(a, b)
		return a.t_when > b.t_when
	end)
end


--
-- Play a note for the given duration using the given sound generator
--

function play(fn, note, vol, dur)
	fn(note, vol or 127)
	at(dur * 0.99, function()
		fn(note, 0)
	end)
end


--
-- Return monotonic time, starts at zero at first invocation
--

function time()
	local s, ns = P.clock_gettime(P.CLOCK_MONOTONIC)
	local t = s + ns / 1e9
	t_start = t_start or t
	return t - t_start
end


--
-- Register the given file descriptor to the main poll() looP. 'fn' is called
-- when new data is available on the fd
--

function watch_fd(fd, fn)
	assert(fn)
	assert(type(fn) == "function")
	fds[fd] = { events = { IN = true }, fn = fn }
end


--
-- Exit event loop
--

local stop_list = {}

function stop()
	for fn in pairs(stop_list) do
		fn()
	end
	running = false
end


function on_stop(fn)
	stop_list[fn] = true
end


P.signal(P.SIGINT, function()
	print("")
	running = false
end)


--
-- Run the main event loop, scheduling timers and handling file descriptors
--

function mainloop()

	while running do

		local dt = 10
		local ev = evs[#evs]

		if ev then
			dt = math.min(ev.t_when - time())
		end

		if dt > 0 then

			local fds2 = {}
			for k, v in pairs(fds) do fds2[k] = v end

			local r, a = P.poll(fds2, dt * 1000)
			if r and r > 0 then
				for fd in pairs(fds2) do
					if fds2[fd].revents and fds[fd].revents.IN then
						t_now = time()
						local ok, rv = safecall(fds2[fd].fn)
						if not ok or rv == false then
							fds[fd] = nil
						end
					end
				end
			end
		end

		while ev and time() > ev.t_when do
			table.remove(evs)
			t_now = ev.t_when
			safecall(ev.fn, unpack(ev.args))
			ev = evs[#evs]
		end

	end
end

-- vi: ft=lua ts=3 sw=3
