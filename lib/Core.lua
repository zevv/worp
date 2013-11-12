
--
-- rl: return a random item from the given list
--

function rl(vs)
	return vs[math.random(1, #vs)]
end


--
-- rr: return a random number from the given range
--

function rr(min, max)
	return math.random(min, max)
end

-- vi: ft=lua ts=3 sw=3
