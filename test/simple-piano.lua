
-- 
-- A simple midi piano using fluidsynth
--

jack = Jack:new("worp")
ls = Linuxsampler:new("synth", "/opt/samples")

midi = jack:midi()

piano = ls:add("piano/Bosendorfer.gig", 0)
midi:map_instr(1, piano)

jack:connect("synth")
jack:connect("worp")

-- vi: ft=lua ts=3 sw=3

