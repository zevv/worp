
--
-- Filter test. White noise generator is passed through a CC controlled filter.
--

Jack = require "jack"
Dsp = require "dsp"

jack = Jack.new("worp")


f = Dsp.filter("lp", 2000, 5)

d = 0
e = 0

jack:midi("midi", function(channel, t, d1, d2)
	if t == "cc" then
		local v = d2 / 127
		if d1 == 1 then f("f0", math.exp(v * 10)) end
		if d1 == 2 then f("Q", math.pow(2, v*3)) end
		if d1 == 3 then f("ft", ({"lp", "hp", "bp", "bs", "ap"})[math.floor(v*4)+1]) end
		if d1 == 4 then f("gain", (v - 0.5) * 30) end
		if d1 == 5 then d = v end
		if d1 == 6 then e = v end
	end
end)


o = Dsp.osc(60)
s = Dsp.saw(90.5)

print(s)

r = Dsp.reverb()

function rl(ns)
	return ns[math.random(1, #ns)]
end

p = 0.5
a2 = 0.02
env = 0 

function rev()
	p = math.random() - 0.5
	e = math.random(1, 6)
	d = math.random() * 0.3 + 0.30
	env = 1
	at(rl { 1, 2, 3 } * .15, "rev")
	a2 = math.random() * 0.03
	at(0.15 * rl { 1 }, function()
		oo2 = Dsp.osc(math.random(10, 600))
		at(0.15/2 * rl { 1, 2 }, function()
			a2 = 0
		end)
	end)
end

oo1 = Dsp.osc(9000)
oo2 = Dsp.osc(100)
o2 = function() oo1(oo2() * 2000 + 10000) return oo1() end
--o2 = Dsp.osc(10000)
rev()

sawvol = 0.04
damp = 0.99995

jack:dsp("fx", 0, 2, function(t)
	local v = env * o() + s() * sawvol
	env = env * damp
	local w = r(v * d) + v * d
	v = f(v + w^math.floor(e*10))
	local vl, vr = p * v * 0.2, v*0.2 * (1-p)
	local bip = o2() * a2
	vl = vl + bip
	vr = vr - bip
	return vl, vr
end)


jack:autoconnect("worp:fx-out-1")
jack:autoconnect("worp:fx-out-2")
jack:autoconnect("worp:midi-in")


-- vi: ft=lua ts=3 sw=3

