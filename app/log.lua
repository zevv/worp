--
-- Copyright © 2007 Ico Doornekamp. All Rights Reserved.
--

LG_FTL = 1
LG_WRN = 2
LG_INF = 3
LG_DBG = 4
LG_DMP = 5

local logf_level_class = {}
local logf_level_global = LG_INF
local logf_busy = false
local logf_use_color = true
local logf_trace_on_warn = false


local level_info = { 
	[LG_FTL] = { "ftl", "\027[7;31m",  2 },
 	[LG_WRN] = { "wrn", "\027[31m",  4 },
 	[LG_INF] = { "inf", "\027[1m",  5 },
 	[LG_DBG] = { "dbg", "\027[22m", 7 },
 	[LG_DMP] = { "dmp", "\027[1;30m", 7 },
}


function logf_init(level)
	if type(level) == "string" then
		for part in level:gmatch("[^,]+") do
			local k,v = part:match("([_%w]+)=(%d)")
			if k and v then
				logf_level_class[k] = tonumber(v)
			else
				logf_level_global = tonumber(part)
			end
		end
	else
		logf_level_global = level
	end
	logf_use_color = p.isatty(0)
end


function logc(level, class, msg, ...)
	assert(level)
	assert(type(level) == "number")
	assert(type(msg) == "string")

	local level2 = logf_level_class[class] or logf_level_global
	if level > level2 then
		return
	end

	msg = string.format(msg, ...)

	if logf_trace_on_warn and (level == LG_WRN or level == LG_FTL) then
		msg = msg .. debug.traceback("", 2)
	end

	if logf_busy then
		if level == LG_FTL then
			os.exit(1)
		end
		return
	end

	local levelstr = level_info[level][1]
	local levelcolor = level_info[level][2]
	local levelsyslog = level_info[level][3]

	-- Log each line separately

	local line = 1

	for msg in msg:gmatch("([^\n]+)") do

		-- Fix unprintable chars
	
		msg = msg:gsub("([^%C	])", function(c) return "<%02x>" % c:byte() end )
		if line > 1 then msg = "| " .. msg end

		-- Log to console
		
		logf_busy = true

		-- Create timestamp. Intra-second timestamps show usec, otherwise
		-- normale date/time stamp

		local t_now = os.time()
		local timestamp = os.date("%y-%m-%d %H:%M:%S", t_now)
		
		local c = class:sub(-10, -1)
		io.stderr:write(string.format("%s %s%s|%-10.10s|%s%s\n",
			timestamp,
			logf_use_color and levelcolor or "", 
			levelstr, 
			c,
			msg,
			logf_use_color and "\027[0m" or ""
		))
			
		line = line + 1
	end
	
	-- Fatal messages abort the application.
	
	if level == LG_FTL then
		error("Fatal error")
	end

	logf_busy = false

	return nil, msg
end


function logf(level, msg, ...)

	assert(level)
	assert(type(level) == "number")
	assert(type(msg) == "string")

	local class = "?"
	local di = debug.getinfo(2, "S")
	if di then
		class = di.source:match("[^/@]+$")
		class = class:gsub("%.lua", "")
	end

	logc(level, class, msg, ...)
end

_G.logf = logf

-- vi: ft=lua ts=3 sw=3
