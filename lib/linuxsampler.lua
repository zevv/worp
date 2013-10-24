
-- 
-- Simple LSCP interface to configure and play linuxsampler. The code below
-- implements a asynchronous interface to make sure not to block the main
-- thread while waiting for linuxsampler to reply.
--

local function cmd(ls, data)

	logf(LG_DMP, "tx> %s", data)
	P.send(ls.fd, data .. "\n")
	
	if coroutine.running() then
		ls.rx_fn = resumer()
		return coroutine.yield()
	else
		ls.rx_fn = function() end
	end
end


local function add(ls, name, fname, index)

	fname = ls.path .. "/" .. fname

	local driver = ls:cmd("CREATE AUDIO_OUTPUT_DEVICE JACK NAME=%q" % name)

	if driver then
		ls:cmd("SET AUDIO_OUTPUT_CHANNEL_PARAMETER %d 0 NAME='out_1'" % driver)
		ls:cmd("SET AUDIO_OUTPUT_CHANNEL_PARAMETER %d 1 NAME='out_2'" % driver)
	end

	local ch = ls:cmd("ADD CHANNEL")
	ls:cmd("LOAD ENGINE gig %d" % ch)
	ls:cmd("SET CHANNEL AUDIO_OUTPUT_DEVICE %d 0" % ch)
	ls:cmd("LOAD INSTRUMENT %q %d %d" % { fname, index or 0, ch })

	local info = ls:cmd("GET CHANNEL INFO %d" % ch)
	local inst = info:match("INSTRUMENT_NAME: ([^\n\r]+)") or "-"
	logf(LG_INF, "linuxsampler %q channel %d: %s", name, ch, inst)

	return function(onoff, key, vel)
		if onoff then
			ls:cmd("SEND CHANNEL MIDI_DATA NOTE_ON %d %d %d\n" % { ch, key, vel * 127 })
		else
			ls:cmd("SEND CHANNEL MIDI_DATA NOTE_OFF %d %d %d\n" % { ch, key, vel * 127 })
		end
	end

end


local function new(path)

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

		-- data

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
			local rv = l:match("^OK%[?(%d*)%]?") or l:match("^%.") or l:match("^$")
			local err = l:match("ERR:(.+)") or l:match("WRN:(.+)")
			if rv then
				ls.rx_fn(rv and tonumber(rv) or ls.rx_buf)
			elseif err then
				ls.rx_fn(nil, err)
			else
				ls.rx_buf = ls.rx_buf .. l .. "\n"
			end
		end
	end)

	ls:cmd("RESET")

	return ls

end


return {
   new = new,
}

-- vi: ft=lua ts=3 sw=3

