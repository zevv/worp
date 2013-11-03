
-- 
-- A simple midi piano using fluidsynth
--

jack = Jack:new("worp")
fs = Fluidsynth:new("synth", "/usr/share/sounds/sf2/FluidR3_GM.sf2")

midi = jack:midi(1)

piano = fs:add(1)

midi:map_instr(1, piano)

jack:connect("synth")
jack:connect("worp")

-- vi: ft=lua ts=3 sw=3

