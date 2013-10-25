
-- 
-- Simple LSCP interface to configure and play linuxsampler. The code below
-- implements a asynchronous interface to make sure not to block the main
-- thread while waiting for linuxsampler to reply.
--

--
-- Execute a linuxsampler command and returns the results. This function
-- assumes the caller is running in a coroutine if an answer is required
--

local function cmd(ls, data)

	logf(LG_DMP, "tx> %s", data)
	P.send(ls.fd, data .. "\n")
	ls.rx_buf = ""
	
	if coroutine.running() then
		ls.rx_fn = resumer()
		return coroutine.yield()
	else
		ls.rx_fn = function() end
	end
end


--
-- Add a linuxsampler channel and load the instrument from the given file and
-- index, return instrument function
--

local function add(ls, fname, index)

	fname = ls.path .. "/" .. fname

	local ch = ls:cmd("ADD CHANNEL")
	ls:cmd("LOAD ENGINE gig %s" % ch)
	ls:cmd("SET CHANNEL AUDIO_OUTPUT_DEVICE %s %s" % { ch, ls.audio_dev })
	ls:cmd("LOAD INSTRUMENT %q %s %s" % { fname, index or 0, ch })

	local info = ls:cmd("GET CHANNEL INFO %s" % ch)
	local inst = info:match("INSTRUMENT_NAME: ([^\n\r]+)") or "-"
	logf(LG_INF, "linuxsampler channel %s: %s", ch, inst)
	
	return function(onoff, key, vel)
		if onoff then
			ls:cmd("SEND CHANNEL MIDI_DATA NOTE_ON %s %s %s\n" % { ch, key, vel * 127 })
		else
			ls:cmd("SEND CHANNEL MIDI_DATA NOTE_OFF %s %s %s\n" % { ch, key, vel * 127 })
		end
	end

end


--
-- Send noteoff to all active channels
--

local function reset(ls)
	local cs = ls:cmd("LIST CHANNELS")
	for c in cs:gmatch("%d+") do
		ls:cmd("SEND CHANNEL MIDI_DATA CC %s 120 0" % c)
	end
end


--
-- Create new linuxsampler connection and create jack audio client
-- with the given name.
--

local function new(_, name, path)

	local fd, err = P.socket(P.AF_INET, P.SOCK_STREAM, 0)
	if not fd then
		return logf(LG_WRN, "Error connecting to linuxsampler: %s", err)
	end

	local ok, err = P.connect(fd, { family = P.AF_INET, addr = "127.0.0.1", port = 8888 })
	if not ok then
		return logf(LG_WRN, "Error connecting to linuxsampler: %s", err)
	end
	
	local ls = {

		-- methods
		
		add = add,
		cmd = cmd,
		reset = reset,

		-- data

		name = name,
		path = path or "",
		fd = fd,
		tx_queue = {},
		rx_buf = "",

	}

	watch_fd(fd, function()
		local data = P.recv(fd, 1024)
		if not data then
			logf(LG_WRN, "Connection to linuxsampler lost")
			return false
		end
		for l in data:gmatch("([^\r\n]*)[\n\r]+") do
			logf(LG_DMP, "rx> %s", l)
			local rv = l:match("^OK%[?(%d*)%]?") or l:match("^%.") or l:match("^([%d,]*)$")
			local err = l:match("ERR:(.+)") or l:match("WRN:(.+)")
			if rv then
				ls.rx_fn(#ls.rx_buf > 0 and ls.rx_buf or rv)
			elseif err then
				ls.rx_fn(nil, err)
			else
				ls.rx_buf = ls.rx_buf .. l .. "\n"
			end
		end
	end)
	
	-- Find existing audio dev with given name, or create if needed

	local ds = ls:cmd("LIST AUDIO_OUTPUT_DEVICES")
	for d in ds:gmatch("%d+") do
		local info = ls:cmd("GET AUDIO_OUTPUT_DEVICE INFO %d" % d)
		local name2 = info:match("NAME: '(.-)'")
		if name == name2 then
			ls.audio_dev = d
		end
	end

	if not ls.audio_dev then
		ls.audio_dev = ls:cmd("CREATE AUDIO_OUTPUT_DEVICE JACK NAME=%q" % name)
		ls:cmd("SET AUDIO_OUTPUT_CHANNEL_PARAMETER %d 0 NAME='out_1'" % ls.audio_dev)
		ls:cmd("SET AUDIO_OUTPUT_CHANNEL_PARAMETER %d 1 NAME='out_2'" % ls.audio_dev)
	end

	return ls

end


return {
   new = new,
}

-- vi: ft=lua ts=3 sw=3

