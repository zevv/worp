
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
-- Simple getopt
--

function getopt(arg_in, optstring)

	local opt_out = {}
	local arg_out = {}

	while arg_in[1] do
		local char, val = string.match(arg_in[1], "^-(.)(.*)") 
		if char then 
			local found, needarg = string.match(optstring, "(" ..char .. ")(:?)") 
			if not found then 
				print("Invalid option '%s'\n" % char)
				return nil
			end 
			if needarg == ":" then 
				if not val or string.len(val)==0 then 
					table.remove(arg, 1)
					val = arg_in[1] 
				end 
				if not val then 
					print("option '%s' requires an argument\n" % char)
					return nil
				end 
			else
				val = true
			end 
			opt_out[char] = val
		else
			table.insert(arg_out, arg_in[1])
		end 
		table.remove(arg_in, 1)
	end 
	return opt_out, arg_out
end 


function sleep(d)
	at(d, resumer())
	coroutine.yield()
end


--
-- Return function that will resume the running coroutine, propagating
-- errors
--

function resumer(co)
	co = co or coroutine.running()
	return function(...)
		local function aux(ok, ...)
			if ok then
				return ...
			else
				print(... .. debug.traceback(co, "", 1), 0)
			end
		end
		return aux(coroutine.resume(co, ...))
	end
end

-- vi: ft=lua ts=3 sw=3
