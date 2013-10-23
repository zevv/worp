
-- 
-- Simple LSCP interface to configure and play linuxsampler. The code below
-- implements a asynchronous interface to make sure not to block the main
-- thread while waiting for linuxsampler to reply.
--
	
local function do_tx(ls)
	if not ls.rx_fn and #ls.tx_queue > 0 then
		local msg = table.remove(ls.tx_queue, 1)
		p.send(ls.fd, msg.data .. "\n")
		logf(LG_DMP, "tx> %s", msg.data)
		ls.rx_fn = msg.fn or function() end
	end
end


local function tx(ls, data, fn)
	ls.rx_buf = ""
	table.insert(ls.tx_queue, { data = data, fn = fn })
	do_tx(ls)
end


local function add(ls, name, fname, index)

	fname = ls.path .. "/" .. fname

	local channel

	tx(ls, "CREATE AUDIO_OUTPUT_DEVICE JACK NAME=%q" % name, function(ok, driver)
		if ok then
			tx(ls, "SET AUDIO_OUTPUT_CHANNEL_PARAMETER %d 0 NAME='out_1'" % driver)
			tx(ls, "SET AUDIO_OUTPUT_CHANNEL_PARAMETER %d 1 NAME='out_2'" % driver)
			tx(ls, "SET AUDIO_OUTPUT_CHANNEL_PARAMETER %d 0 JACK_BINDINGS='system:playback_1'" % driver)
			tx(ls, "SET AUDIO_OUTPUT_CHANNEL_PARAMETER %d 1 JACK_BINDINGS='system:playback_2'" % driver)
		end
		tx(ls, "ADD CHANNEL", function(ok, ch)
			tx(ls, "LOAD ENGINE gig %d" % { ch })
			tx(ls, "SET CHANNEL AUDIO_OUTPUT_DEVICE %d 0" % { ch })
			tx(ls, "LOAD INSTRUMENT %q %d %d" % { fname, index or 0, ch })
			tx(ls, "GET CHANNEL INFO %d" % ch, function(ok, data)
				local inst = data:match("INSTRUMENT_NAME: ([^\n\r]+)") or "-"
				logf(LG_INF, "linuxsampler %q channel %d: %s", name, ch, inst)
			end)
			at(1, function()
				channel = ch
			end)
		end)
	end)

	return function(onoff, key, vel)
		if channel then
			if onoff then
				tx(ls, "SEND CHANNEL MIDI_DATA NOTE_ON %d %d %d\n" % { channel, key, vel * 127 })
			else
				tx(ls, "SEND CHANNEL MIDI_DATA NOTE_OFF %d %d %d\n" % { channel, key, vel * 127 })
			end
		end
	end

end


local function new(path)

	local fd, err = p.socket(p.AF_INET, p.SOCK_STREAM, 0)
	if not fd then
		return logf(LG_WRN, "Error connecting to linuxsampler: %s", err)
	end

	local ok, err = p.connect(fd, { family = p.AF_INET, addr = "127.0.0.1", port = 8888 })
	if not ok then
		return logf(LG_WRN, "Error connecting to linuxsampler: %s", err)
	end
	
	local ls = {

		-- methods
		
		add = add,
		tx = tx,

		-- data

		path = path or "",
		fd = fd,
		tx_queue = {},
		rx_fn = nil,
		rx_buf = "",

	}

	watch_fd(fd, function()
		local data = p.recv(fd, 1024)
		if not data then
			logf(LG_WRN, "Connection to linuxsampler lost")
			return false
		end
		for l in data:gmatch("[^\r\n]+") do
			logf(LG_DMP, "rx> %s", l)
			local rv = l:match("^OK%[?(%d*)%]?") or l:match("^%.")
			local err = l:match("ERR:(.+)") or l:match("WRN:(.+)")
			if rv then
				if ls.rx_fn then ls.rx_fn(true, rv and tonumber(rv) or ls.rx_buf) end
				ls.rx_fn = nil
				do_tx(ls)
			elseif err then
				if ls.rx_fn then ls.rx_fn(false, err) end
				ls.rx_fn = nil
				do_tx(ls)
			else
				ls.rx_buf = ls.rx_buf .. l .. "\n"
			end
		end
	end)

	tx(ls, "RESET")

	return ls

end


return {
   new = new,
}

-- vi: ft=lua ts=3 sw=3

