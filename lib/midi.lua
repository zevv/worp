

local function new(fname)

   local fd = p.open(fname, p.O_RDWR)

   local cb_list = {
      key = {},
      pot = {}
   }

   local function each_cb(t, fn)
      for _, i in pairs(cb_list[t]) do
         fn(i)
      end
   end

   watch_fd(fd, function()

      local msg = p.read(fd, 3)
      local a, b, c = msg:byte(1, 3)
--      print(a, b, c)
            
      local type = bit.band(a, 0xf0)
      local chan = bit.band(a, 0x0f) + 1
      
      if type == 0x90 or type == 0x80 then
         each_cb("key", function(i)
            if i.chan == chan then
               i.fn(type == 0x90, chan, b, c/127)
            end
         end)
      end

      if type == 0xb0 then
         each_cb("pot", function(i)
            if (not i.chan or i.chan == chan) and (not i.pot or i.pot == b) then
               i.fn(chan, b, c/127)
            end
         end)
      end
         
   end)

   return {
      on_key = function(_, chan, fn)
         table.insert(cb_list.key, { chan = chan, fn = fn })
      end,

      on_pot = function(_, chan, pot, fn)
         table.insert(cb_list.pot, { chan = chan, pot = pot, fn = fn })
      end,

      note = function(_, onoff, chan, note, vel)
         local msg = string.char(
            (onoff and 0x90 or 0x80) + chan - 1,
            note, vel)
            print((onoff and 0x90 or 0x80) + chan - 1,
                        note, vel)
         p.write(fd, msg)
      end,

   }
end


return {
   new = new,
}

-- vi: ft=lua ts=3 sw=3

