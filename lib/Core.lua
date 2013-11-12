
--
-- The Core library defines some handy low level functions:
--
--   rl(LIST): return a random item from the given list
--   rr(MIN, MAX): return a random number from the given range
--

function rl(vs)
	return vs[math.random(1, #vs)]
end

function rr(min, max)
	return min + math.random() * (max-min)
end

-- vi: ft=lua ts=3 sw=3
