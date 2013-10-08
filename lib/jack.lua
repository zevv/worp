
local jack_c = require "jack_c"

local function new(name, port_list, fn)

   local j, fd, srate, bsize = jack_c.open(name, port_list)

   print("Create", j, fd, srate, bsize)

   local t = 0

   watch_fd(fd, function()
     
      p.read(fd, 1)

      local ok = safecall(function()
         for i = 1, bsize do
            jack_c.write(j, fn(t, jack_c.read(j)))
            t = t + 1/srate
         end
      end)
   end)

	return {
		connect = function(_, p1, p2)
			return jack_c.connect(j, p1, p2)
		end,

		disconnect = function(_, p1, p2)
			return jack_c.disconnect(j, p1, p2)
		end,
	}

end


return {
   new = new
}

-- vi: ft=lua ts=3 sw=3

