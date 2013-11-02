
--
-- GUI process. This is a forked subprocess handling the GTK gui
--

local lgi, GLib, Gtk, Gdk 



local cmd_handler = {

	new = function(worker, id, data)

		local window = Gtk.Window {
			title = data.gui_id,
			width = 400,
			Gtk.Box {
				id = "box",
				border_width = 4,
				orientation = 'VERTICAL', 
				{
					Gtk.Label {
						use_markup = true,
						label = "<b>" .. data.gui_id .. "</b>",
					}
				}
			}
		}
	
		worker.gui_list[data.gui_id] = {
			window = window,
			group_list = {},
		}
		window:show_all()

	end,


	add_group = function(worker, id, data)
	
		local gui = worker.gui_list[data.gui_id]
		local info = data.info
		local mute = false

		gui.window.child.box:add {
			Gtk.Frame {
				label = data.group_id,
				shadow_type = 'OUT',
				margin = 5,
				Gtk.Grid {
					margin = 5,
					row_spacing = 5,
					column_spacing = 5,
					id = data.group_id,
				}
			}
		}
		
		gui.window:show_all()
	
		gui.group_list[data.group_id] = {
			y = 0,
			control_list = {}
		}

	end,


	add_control = function(worker, id, data)
		
		local gui = worker.gui_list[data.gui_id]
		local group = gui.group_list[data.group_id]

		local window = gui.window
		local grid = window.child[data.group_id]

		local y = group.y
		group.y = group.y + 1

		local control = data.control
		local mute = false
		local fn_set = function(v) end
		
		grid:add {
			left_attach = 0, top_attach = y,
			Gtk.Label {
				label = control.description,
				halign = 'START',
				valign = 'END',
			}
		}

		local type = "number"
		if control.range:find(",") then type = "enum" end

		local id = "%s-%s-%s" % { data.gui_id, data.group_id, control.id }

		if type == "number" then
		
			local min, max = control.range:match("(.+)%.%.(.+)")
			min = tonumber(min) or 0
			max = tonumber(max) or 1

			local adjustment = Gtk.Adjustment {
				lower = min,
				upper = max,
				step_increment = (max-min)/1000,
				page_increment = (max-min)/10,
			}

			local label = Gtk.Label {
				halign = 'END',
			}

			local function on_value_changed(s)
				local fmt = control.fmt or "%.1f"
				local val = s.adjustment.value
				if control.log then
					if val < 0.001 then val = 0.001 end
					val = (max+1) ^ (val/max) - 1
				end
				val = fmt % val
				label:set_text(val)
				if not mute then
					worker:tx { cmd = "set", data = {
						uid = data.uid,
						control_id = control.id,
						value = val,
					}}
				end
			end

			fn_set = function(val)
				if control.log then
					val = (max) * math.log(val+1) / math.log(max)
				end
				mute = true
				adjustment:set_value(val)
				mute = false
			end

			grid:add {
				left_attach = 1, top_attach = y,
				Gtk.Scale {
					adjustment = adjustment,
					hexpand = true,
					draw_value = false,
					on_value_changed = on_value_changed
				}
			}

			grid:add {
				left_attach = 3, top_attach = y,
				label,
			}

			grid:add {
				left_attach = 4, top_attach = y,
				Gtk.Label {
					label = control.unit or "",
					halign = 'START',
				},
			}

		else

			local t = {}
			for v in control.range:gmatch("[^,]+") do
				t[#t+1] = v
				t[v] = #t
			end

			grid:add {
				left_attach = 1, top_attach = y,
				Gtk.ComboBoxText {
					on_changed = function(s)
					end
				}
			}

		end
	
		group.control_list[control.id] = {
			control = control,
			fn_set = fn_set,
		}

		window:show_all()
	end,


	set_control = function(worker, id, data)

		local gui = worker.gui_list[data.gui_id]
		local group = gui.group_list[data.group_id]
		local control = group.control_list[data.control_id]
		control.fn_set(data.value)

	end

}


local function handle_msg(worker, code)
	local fn, err = load("return " .. code)
	if fn then
		local ok, msg = safecall(fn)
		if ok then
			local h = cmd_handler[msg.cmd]
			if h then
				h(worker, msg.genid, msg.data)
			end
		else
			logf(LG_WRN, "ipc error: %s", data)
		end
	else
		logf(LG_WRN, "ipc error: %s", err)
	end
end


local function gui_main(fd)

	lgi = require "lgi"
	GLib, Gtk, Gdk = lgi.GLib, lgi.Gtk, lgi.Gdk
		
	local worker = {

		-- methods

		tx = function(worker, msg)
			P.send(fd, serialize(msg))
		end,

		-- data

		fd = fd,
		gui_list = {}
	}

	-- Main GTK loop: receive messages from main process and handle GUI
	
	local ioc = GLib.IOChannel.unix_new(worker.fd)
	GLib.io_add_watch(ioc, 1, 1, function(a, b, c ,d)
		local code, err = P.recv(worker.fd, 65535)
		if code then
			handle_msg(worker, code)
		end
		return true
	end)

	Gtk.main()

end


--
-- Main process
--


local function group_add_control(group, control, uid, fn_set)

	group.gui.Gui:tx { cmd = "add_control", data = { 
		gui_id = group.gui.gui_id, 
		group_id = group.id, 
		control = control,
		uid = uid,
	}}
	
	if control.default then
		group.gui.Gui:tx { cmd = "set_control", data = { 
			gui_id = group.gui.gui_id, 
			group_id = group.id, 
			control_id = control.id,
			value = control.default}}
	end

	--group.gui.fn_set[id] = fn_set
end


local function gui_add_group(gui, group_id)
	
	local group = {

		-- methods
		
		add_control = group_add_control,

		-- data

		gui = gui,
		id = group_id,
	}

	
	gui.Gui:tx { cmd = "add_group", data = { 
		gui_id = gui.gui_id, 
		group_id = group.id }}

	return group

end


local function gui_start(Gui)
	local s1, s2 = P.socketpair(P.AF_UNIX, P.SOCK_DGRAM, 0)
	Gui.pid = P.fork()
	if Gui.pid == 0 then
		for i = 3, 255 do
			if i ~= s2 then P.close(i) end
		end
		gui_main(s2)
	end
	P.close(s2)
	Gui.s = s1
	Gui.uid_to_gen = {}

	watch_fd(s1, function()
		local code = P.recv(s1, 65535)
		local fn, err = load("return " .. code)
		if fn then
			local ok, msg = safecall(fn)
			if ok then
				if msg.cmd == "set" then
					local gen = Gui.uid_to_gen[msg.data.uid]
					if gen then
						gen:set { [msg.data.control_id] = msg.data.value }
					end
				end
			else
				logf(LG_WRN, "ipc error: %s", data)
			end
		else
			logf(LG_WRN, "ipc error: %s", err)
		end
	end)

	Gui.tx = function(_, msg)
		P.send(Gui.s, serialize(msg))
	end
end


local function gui_add_gen(gui, gen)

	local uid = "%08x" % math.random(0, 0xffffffff)
	gui.Gui.uid_to_gen[uid] = gen

	local info = gen:info()
	local group = gui:add_group(info.description)
	for _, control in ipairs(info.controls) do
		group:add_control(control, uid, function(v)
			gen:set { [control.id] = v }
		end)
	end
end


local function new(Gui, gui_id)

	if not Gui.pid then
		gui_start(Gui)
	end
	
	local gui = {

		-- methods

		add_group = gui_add_group,
		add_gen = gui_add_gen,

		-- data

		gui_id = gui_id,
		Gui = Gui,

	}
	
	gui.Gui:tx { cmd = "new", data = { gui_id = gui_id } }

	return gui

end


return {
   new = new,
}

-- vi: ft=lua ts=3 sw=3
