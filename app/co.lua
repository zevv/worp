
--
-- Coroutine shortcuts
--

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
