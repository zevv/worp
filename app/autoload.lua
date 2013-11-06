
local mtime = {}

function autoload(id, parent, path)
	
	local function lookup(env, s)

		-- Check if parent provides

		local v = rawget(parent, s)
		if v then return v end

		-- Check if it is a lib we can load

		local fname = "%s/%s.lua" % { path, s }
		local stat = P.stat(fname)
		if stat and stat.type == "regular" then
			logf(LG_DBG, "Loading library %s", fname)
			local chunk, err = loadfile(fname, "t", env)
			if chunk then
				local ok = safecall(chunk)
				if not ok then
					logf(LG_WRN, "%s", err)
				end
			else
				logf(LG_WRN, "%s", err)
			end
			local v = rawget(env, s)
			if v then return v end
		end

		-- Check if lib subdirectory

		local fname = "%s/%s" % { path, s }
		local stat = P.stat(fname)
		if stat and stat.type == "directory" then
			return autoload(path, sandbox.env, "lib/" .. s)
		end

		-- Fallback

		return parent[s]
	end

	return setmetatable({}, {
		__index = function(env, s)
			v = lookup(env, s)
			env[s] = v
			return v
		end,
		__tostring = function(t)
			return "Autoload library %q" % id
		end,
	})

end

-- vi: ft=lua ts=3 sw=3
