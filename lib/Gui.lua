
--
-- See the [gui] documentation page
--

Gui = {}


--
-- GUI process. This is a forked subprocess handling the GTK gui
--

local lgi, GLib, Gtk, Gdk 

local function random_id()
	return "%08x" % math.random(0, 0xffffffff)
end

--
-- Implementation of knob widget
--

local function Knob(parm)

	local size = 40
	local w, h
	local cx = size * 0.5
	local cy = size * 0.5
	local r = size * 0.45
	local value = 0
	local def = parm.default
	local min = parm.lower
	local max = parm.upper
	local range = max - min
	local drag_x, drag_y, dragging = 0, 0, false
		
	local da = Gtk.DrawingArea { 
		width = size,
		height = size,
		can_focus = true,
	}
	
	local knob = {

		da = da,

		set_value = function(knob, v)
			v = math.max(v, min)
			v = math.min(v, max)
			value = v
			da.window:invalidate_rect(nil)
			parm.on_value_changed(knob)
		end,

		get_value = function(knob)
			return value 
		end
	}

	local sc = da:get_style_context()

	function da:on_draw(cr)

		local function v2a(v)
			return (v - min) / range * 5 + 2.25
		end

		local function l(v, r1, r2)
			local a = v2a(v)
			local x, y = math.cos(a), math.sin(a)
			cr:move_to(cx + x * r * r1, cy + y * r * r1)
			cr:line_to(cx + x * r * r2, cy + y * r * r2)
			cr:stroke()
		end
		
		cr:set_line_width(1)

		cr:arc(cx, cy, r, 0, 6.28)
		cr:set_source_rgb(0.7, 0.7, 0.7)
		cr:fill_preserve()
		cr:set_source_rgb(0.9, 0.9, 0.9)
		cr:stroke()
		
		cr:arc(cx, cy, r*0.7, 0, 6.28)
		cr:set_source_rgb(0.5, 0.5, 0.5)
		cr:fill_preserve()
		cr:set_source_rgb(0.3, 0.3, 0.3)
		cr:stroke()
		
		cr:set_line_width(2)
		local a1, a2 = v2a(0), v2a(value)
		cr:arc(cx, cy, r*0.85, math.min(a1, a2), math.max(a1, a2))
		cr:set_source_rgb(0.0, 1.0, 0.0)
		cr:stroke()

		cr:set_line_width(2)
		cr:set_source_rgb(0.0, 0.0, 0.0)
		l(min, 0.7, 0.9)
		l(max, 0.7, 0.9)
		if def ~= min and def ~= max then
			l(def, 0.8, 0.9)
		end
		
		cr:set_line_width(3)
		cr:set_source_rgb(1.0, 1.0, 1.0)
		l(value, 0, 0.6)
		
		cr:set_line_width(1)

		if da.has_focus then
			Gtk.render_focus(sc, cr, 0, 0, w, h)
		end

	end

	function da:on_configure_event(event)
		w, h = self.allocation.width, self.allocation.height
		cx, cy = w/2, h/2
		return true
	end
	
	function da:on_scroll_event(event)
		local d = 0
		if event.direction == 'UP'   then d =  parm.page_increment end
		if event.direction == 'DOWN' then d = -parm.page_increment end
		if event.state.SHIFT_MASK then d = d / 10 end
		if event.state.CONTROL_MASK then d = d * 10 end
		knob:set_value(value + d)
	end
	
	function da:on_button_press_event(event)
		da.has_focus = true 
	end

	function da:on_motion_notify_event(event)
		local _, x, y, state = event.window:get_device_position(event.device)

		if not dragging and state.BUTTON1_MASK then dragging, drag_x, drag_y = true, x, y end
		if dragging and not state.BUTTON1_MASK then dragging = false end

		if dragging then
			local dy = drag_y - y
			knob:set_value(value + dy * range / 100)
			da.window:invalidate_rect(nil)
			drag_y = y
		end
	end

	function da:on_key_press_event(event)
		local d = 0
		local k = event.keyval
		if k == Gdk.KEY_Up then d = parm.step_increment end
		if k == Gdk.KEY_Down then d = -parm.step_increment end
		if k == Gdk.KEY_Page_Up then d = parm.page_increment end
		if k == Gdk.KEY_Page_Down then d = -parm.page_increment end
		if event.state.SHIFT_MASK then d = d / 10 end
		if event.state.CONTROL_MASK then d = d * 10 end
		knob:set_value(value + d)
	end

	da:add_events(Gdk.EventMask {
		'SCROLL_MASK',
		'KEY_PRESS_MASK',
		'BUTTON_PRESS_MASK',
		'LEAVE_NOTIFY_MASK',
		'BUTTON_PRESS_MASK',
		'POINTER_MOTION_MASK',
		'POINTER_MOTION_HINT_MASK' })

	return knob

end



local cmd_handler = {

	new = function(worker, id, data)

		local window = Gtk.Window {
			--resizable = false,
			title = data.gui_id,
			Gtk.Box {
				id = "box",
				valign = 'START',
				orientation = 'HORIZONTAL', 
				{
					Gtk.Label {
						use_markup = true,
						label = data.label and "<b>" .. data.label .. "</b>" or nil,
					},
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

		local frame = Gtk.Frame {
			label = data.label,
			margin = 4,
			Gtk.Grid {
				margin = 4,
				column_spacing = 4,
				id = data.group_id,
			}
		}

		frame:set_label_align(0.5, 1)

		gui.window.child.box:add(frame)
		
		gui.window:show_all()
	
		gui.group_list[data.group_id] = {
			index = 0,
			control_list = {}
		}

	end,


	add_control = function(worker, id, data)
		
		local gui = worker.gui_list[data.gui_id]
		local group = gui.group_list[data.group_id]

		local window = gui.window
		local grid = window.child[data.group_id]

		local x = group.index
		group.index = group.index + 1

		local control = data.control
		local mute = false
		local fn_set = function(v) end
		
		grid:add {
			left_attach = x, top_attach = 0,
			Gtk.Label {
				label = control.id,
				halign = 'CENTER',
			}
		}

		if control.type == "number" then

			local label = Gtk.Label {
				halign = 'CENTER',
			}
	
			local function k2v(v)
				if control.log then
					if v < 0.001 then v = 0.001 end
					v = (control.max+1) ^ (v/control.max) - 1
				end
				return v
			end
			
			local function v2k(v)
				if control.log then
					v = (control.max) * math.log(v+1) / math.log(control.max)
				end
				return v
			end

			local function on_value_changed(knob)
				local val = k2v(knob:get_value())
				if not mute then
					worker:tx { cmd = "set", data = {
						uid = data.uid,
						value = val,
					}}
				end
				local unit = control.unit
				if val > 1000 then
					val = val / 1000
					unit = "k" .. unit
				end
				local fmt = "%d"
				if math.abs(val) < 100 then fmt = "%.1f" end
				if math.abs(val) < 10 then fmt = "%.2f" end
				if control.unit then
					fmt = fmt .. " " .. unit
				end
				label:set_text((control.fmt or fmt) % val)
			end

			local knob = Knob {
				lower = v2k(control.min),
				upper = v2k(control.max),
				default = v2k(control.default),
				step_increment = (control.max-control.min)/100,
				page_increment = (control.max-control.min)/10,
				on_value_changed = on_value_changed,
			}

			grid:add {
				left_attach = x, top_attach = 1,
				knob.da 
			}

			grid:add {
				left_attach = x, top_attach = 2,
				label,
			}

			fn_set = function(val)
				mute = true
				knob:set_value(v2k(val))
				mute = false
			end


		elseif control.type == "enum" then

			local combo = Gtk.ComboBoxText {
				on_changed = function(s)
					worker:tx { cmd = "set", data = {
						uid = data.uid,
						value = s:get_active_text(),
					}}
				end
			}

			grid:add {
				left_attach = x, top_attach = 1,
				combo
			}

			for i, o in ipairs(control.options) do
				combo:append(i-1, o)
			end

			fn_set = function(v)
				for i, o in ipairs(control.options) do
					if v == o then combo:set_active(i-1) end
				end
			end

		elseif control.type == "bool" then

			local switch = Gtk.ToggleButton { 
				label = " ",
				on_toggled = function(s)
					worker:tx { cmd = "set", data = {
						uid = data.uid,
						value = s:get_active()
					}}
				end
			}

			grid:add {
				left_attach = x, top_attach = 1,
				switch,
			}
			
			fn_set = function(v)
				switch:set_active(v)
			end

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
	local fn, err = load("return " .. code, "msg")
	if fn then
		local ok, msg = safecall(fn)
		if ok then
			local h = cmd_handler[msg.cmd]
			if h then
				h(worker, msg.modid, msg.data)
			end
		else
			logf(LG_WRN, "ipc run error: %s", data, code)
		end
	else
		logf(LG_WRN, "ipc syntax error: %s", err)
	end
end


local function gui_main(fd)

	P.signal(P.SIGINT, nil)

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
		gui_id = group.gui.id, 
		group_id = group.id, 
		control = control,
		uid = uid,
	}}

	local function set(val)
		group.gui.Gui:tx { cmd = "set_control", data = { 
			gui_id = group.gui.id, 
			group_id = group.id, 
			control_id = control.id,
			value = val
		}}
	end
	
	control:on_set(set)

	if control.value then
		set(control.value)
	end

	--group.gui.fn_set[id] = fn_set
end


local function gui_add_group(gui, label)
	
	local group = {

		-- methods
		
		add_control = group_add_control,

		-- data

		gui = gui,
		label = label,
		id = random_id(),
	}

	
	gui.Gui:tx { cmd = "add_group", data = { 
		gui_id = gui.id, 
		label = group.label,
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
	Gui.uid_to_control = {}

	watch_fd(s1, function()
		local code = P.recv(s1, 65535)
		local fn, err = load("return " .. code)
		if fn then
			local ok, msg = safecall(fn)
			if ok then
				if msg.cmd == "set" then
					local control = Gui.uid_to_control[msg.data.uid]
					if control then
						control:set(msg.data.value)
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


local function gui_add_mod(gui, gen, label)

	local controls = gen:controls()
	local group = gui:add_group(label or gen.description)
	for _, control in ipairs(controls) do
		local uid = random_id()
		gui.Gui.uid_to_control[uid] = control
		group:add_control(control, uid, function(v)
			gen:set { [control.id] = v }
		end)
	end
end


function Gui:new(label)

	if not Gui.pid then
		gui_start(Gui)
	end
	
	local gui = {

		-- methods

		add_group = gui_add_group,
		add_mod = gui_add_mod,

		-- data

		id = random_id(),
		Gui = Gui,

	}
	
	gui.Gui:tx { cmd = "new", data = { gui_id = gui.id, label = label } }

	return gui

end


-- vi: ft=lua ts=3 sw=3
