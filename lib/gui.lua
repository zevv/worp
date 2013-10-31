
local lgi = require "lgi"
local GLib = lgi.GLib
local Gtk = lgi.Gtk
local Gdk = lgi.Gdk

local mainloop = GLib.MainLoop(nil, false)
local ctx = mainloop.get_context(mainloop)

--local fds = GLib.PollFD()
--print(fds)
--ctx:query(1, 1, fds, 32)
--os.exit(0)

local function iter()
	ctx:iteration()
	at(0.01, iter)
end
at(0.01, iter)

local function add(_, gen)

	local window = Gtk.Window {
		title = "Drawing Area",
		resizable = false,
		width = 400,
		--height = 100,
		Gtk.Box {
			border_width = 4,
			orientation = 'VERTICAL',
			Gtk.Label {
				id = "label"
			},
			Gtk.Grid {
				id = "grid",
			}
		}
	}


	local info = gen:info()
	local val = gen:get()

	window.child.label:set_text(info.description)

	local y = 0

	for _, arg in ipairs(info.args) do

		local type = "number"
		if arg.range:find(",") then type = "enum" end
		local min, max = arg.range:match("(.+)%.%.(.+)")
		min = tonumber(min) or 0
		max = tonumber(max) or 1

		window.child.grid:add {
			left_attach = 0, top_attach = y,
			Gtk.Label {
				label = arg.name,
				use_underline = true,
				halign = 'START',
				valign = 'END',
			}
		}
		
		if type == "number" then

			window.child.grid:add {
				left_attach = 1, top_attach = y,
				Gtk.Scale {
					adjustment = Gtk.Adjustment {
						lower = min,
						upper = max,
						value = tonumber(val[arg.name]),
					},
					hexpand = true,
					draw_value = false,
					on_value_changed = function(s)
						local val = string.format("%.1f", s.adjustment.value)
						window.child["val-" .. arg.name]:set_text(val)
						gen:set { [arg.name] = s.adjustment.value }
					end
				}
			}
	
			window.child.grid:add {
				left_attach = 3, top_attach = y,
				Gtk.Label {
					id = "val-" .. arg.name,
					label = val[arg.name] or ""
				}
			}

			window.child.grid:add {
				left_attach = 4, top_attach = y,
				Gtk.Label {
					label = arg.unit or "",
					halign = 'START',
				},
			}
		else

			local t = {}
			for v in arg.range:gmatch("[^,]+") do
				t[#t+1] = v
				t[v] = #t
			end

			window.child.grid:add {
				left_attach = 1, top_attach = y,
				Gtk.ComboBoxText {
					id = "val-" .. arg.name,
					on_changed = function(s)
						gen:set { [arg.name] = t[s:get_active()+1] }
					end
				}
			}

			local c = window.child["val-" .. arg.name]
			for i, v in ipairs(t) do
				c:append(nil, v)
			end
			c:set_active(t[val[arg.name]]-1)

		end

		y = y + 1
	end

	window:show_all()
--	Gtk.main()
end

--function window.child.scale:on_value_changed()
--	   window.child.bin:set_angle(self.adjustment.value)
--	end


return {
   add = add,
}

-- vi: ft=lua ts=3 sw=3

