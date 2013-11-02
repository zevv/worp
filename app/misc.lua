
--
-- Create a '%' operator on strings for ruby- and python-like formatting
--

getmetatable("").__mod = function(a, b)
   if not b then
      return a
   elseif type(b) == "table" then
      return string.format(a, unpack(b))
   else
      return string.format(a, b)
   end
end


--
-- Fix up line numbers of loaded chunks in stack traces and error messages
--

function fixup_error(msg)
	return msg:gsub('%[string "live (.-):(%d+)"]:(%d+)', function(n, l1, l2)
		return n .. ":" .. (l1+l2-1)
	end)
end


-- 
-- Safe call: calls the given function with an error handler, print error
-- and stacktrace to stdout
--

function safecall(fn, ...)
	local function errhandler(err)
		local msg = debug.traceback("Error: " .. err, 3)
		print(fixup_error(msg))
	end
	if type(fn) == "string" then fn = sandbox_get(fn) end
	return xpcall(fn, errhandler, ...)
end


--
-- Dump lua data structure
--

function dump(obj, maxdepth)

	maxdepth = maxdepth or 999
	local dumped = {}
	local fd = io.stderr

	local function _dumpf(obj, depth)

		local i, n, v

		if(type(obj) == "table") then
			fd:write("{")
			if depth < maxdepth then
				if not dumped[obj] then
					dumped[obj] = true
					for n, v in pairs(obj) do
						fd:write("\n");
						fd:write(string.rep("  ", depth+1))
						_dumpf(n, depth+1);
						fd:write(" = ")
						_dumpf(v, depth+1);
						fd:write(", ")
					end
					fd:write("\n")
					fd:write(string.rep("  ", depth))
				else
					fd:write(" *** ")
				end
			else
				fd:write(" <<< ")
			end
			fd:write("}")
			local mt = getmetatable(obj)
			if mt then
				fd:write(" metatable: ")
				_dumpf(mt, depth)
			end
		elseif(type(obj) == "string") then
			fd:write("%q" % obj)
		elseif(type(obj) == "number") then
			fd:write(obj)
		elseif(type(obj) == "boolean") then
			fd:write(obj and "true" or "false")
		elseif(type(obj) == "function") then
			local i = debug.getinfo(obj)
			fd:write("function(%s:%s)" % { i.short_src, i.linedefined })
		else
			fd:write("(%s)" % type(obj))
		end

		if depth == 0 then 
			fd:write("\n") 
			io.flush()
		end
	end

	_dumpf(obj, 0)
end


--
-- Serialize lua data to string
--

function serialize(o)
	local t = type(o)
	if t == "string" then
		return string.format("%q", o) 
	elseif t == "boolean" then
		return tostring(o)
	elseif t == "number" then
		return tostring(o) 
	elseif t == "table" then
		local out = {}
		local done = {}
		for i, c in ipairs(o) do
			table.insert(out, serialize(c))
			done[i] = true
		end
		for k, c in pairs(o) do
			if not done[k] then
				if type(k) ~= "function" and type(k) ~= "table" then
					table.insert(out, "[" .. serialize(k) .. "]=" .. serialize(c))
				end
			end
		end
		return "{" .. table.concat(out, ",") .. "}"
	else
		return "nil"
	end
end

-- vi: ft=lua ts=3 sw=3
