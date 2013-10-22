
--CREATE AUDIO_OUTPUT_DEVICE JACK
--SET AUDIO_OUTPUT_CHANNEL_PARAMETER 0 0 JACK_BINDINGS='system:playback_1'
--SET AUDIO_OUTPUT_CHANNEL_PARAMETER 0 1 JACK_BINDINGS='system:playback_2'
--
--# load the ALSA MIDI driver
--CREATE MIDI_INPUT_DEVICE ALSA
--SET MIDI_INPUT_PORT_PARAMETER 0 0 ALSA_SEQ_BINDINGS='72:0'
--ADD CHANNEL
--LOAD ENGINE gig 0
--SET CHANNEL AUDIO_OUTPUT_DEVICE 0 0
--SET CHANNEL MIDI_INPUT_DEVICE 0 0
--LOAD INSTRUMENT '/home/me/Gigs/PMI Steinway D.gig' 0 0
--GET CHANNEL INFO 0
--QUIT


local function new(name, fname)

	local fd, err = p.socket(p.AF_INET, p.SOCK_STREAM, 0)
	if not fd then
		return logf(LG_WRN, "Error connecting to linuxsampler: %s", err)
	end

	local ok, err = p.connect(fd, { family = p.AF_INET, addr = "127.0.0.1", port = 8888 })
	if not ok then
		return logf(LG_WRN, "Error connecting to linuxsampler: %s", err)
	end

	watch_fd(fd, function()
		local data = p.recv(fd, 1024)
		if not data then
			logf(LG_WRN, "Connection to linuxsampler lost")
			return false
		end
		for l in data:gmatch("[^\r\n]+") do
			logf(LG_DMP, "> %s", l)
			local err = l:match("ERR:(.+)")
			if err then
				logf(LG_WRN, "linuxsampler: %s", err)
			end
		end
	end)

	p.send(fd, string.format([[
CREATE AUDIO_OUTPUT_DEVICE JACK NAME=%q
ADD CHANNEL
SET AUDIO_OUTPUT_CHANNEL_PARAMETER 0 0 JACK_BINDINGS='system:playback_1'
SET AUDIO_OUTPUT_CHANNEL_PARAMETER 0 1 JACK_BINDINGS='system:playback_2'
LOAD ENGINE gig 0
SET CHANNEL AUDIO_OUTPUT_DEVICE 0 0
LOAD INSTRUMENT %q 0 0
]], name, fname))

	return function(onoff, key, vel)
		vel = math.floor(vel * 127)
		if onoff then
			p.send(fd, "SEND CHANNEL MIDI_DATA NOTE_ON 0 " .. key .. " " .. vel .. "\n")
		else
			p.send(fd, "SEND CHANNEL MIDI_DATA NOTE_OFF 0 " .. key .. " " .. vel .. "\n")
		end
	end

end


return {
   new = new,
}

-- vi: ft=lua ts=3 sw=3

