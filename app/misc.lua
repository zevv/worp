
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


-- vi: ft=lua ts=3 sw=3
