
--
-- GUI process
--

local lgi, GLib, Gtk, Gdk 


local function worker_tx(worker, msg)
	P.send(worker.fd, serialize(msg))
end


local cmd_handler = {

	add = function(worker, id, data)
		
		local info = data.info
		local setting = false

		local window = Gtk.Window {
			title = info.description,
			resizable = false,
			width = 400,
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

		window.child.label:set_text(info.description)
		worker.setter_list[id] = worker.setter_list[id] or {}
		local setter = worker.setter_list[id]
		worker.window_list[id] = window

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
							step_increment = (max-min)/1000,
							page_increment = (max-min)/10,
						},
						id = id .. "-" .. arg.name,
						hexpand = true,
						draw_value = false,
						on_value_changed = function(s)
							local val = s.adjustment.value
							if arg.log then
								if val < 0.001 then val = 0.001 end
								val = (max+1) ^ (val/max) - 1
							end
							local val = string.format("%.1f", val)
							window.child[id .. "-" .. arg.name .. "-label"]:set_text(val)
							if not setting then
								worker_tx(worker, { cmd = "set", genid = id, data = { [arg.name] = val }})
							end
						end
					}
				}

				window.child.grid:add {
					left_attach = 3, top_attach = y,
					Gtk.Label {
						id = id .. "-" .. arg.name .. "-label",
					}
				}

				window.child.grid:add {
					left_attach = 4, top_attach = y,
					Gtk.Label {
						label = arg.unit or "",
						halign = 'END',
					},
				}

				setter[arg.name] = function(val)
					setting = true
					if arg.log then
						val = (max) * math.log(val+1) / math.log(max)
					end
					window.child[id .. "-" .. arg.name].adjustment:set_value(val)
					setting = false
				end
				
			else

				local t = {}
				for v in arg.range:gmatch("[^,]+") do
					t[#t+1] = v
					t[v] = #t
				end

				window.child.grid:add {
					left_attach = 1, top_attach = y,
					Gtk.ComboBoxText {
						id = id .. "-" .. arg.name,
						on_changed = function(s)
							local val = t[s:get_active()+1] 
							worker_tx(worker, { cmd = "set", genid = id, data = { [arg.name] = val }})
						end
					}
				}

				local c = window.child[id .. "-" .. arg.name]
				for i, v in ipairs(t) do
					c:append(nil, v)
				end
				
				setter[arg.name] = function(val)
					setting = true
					c:set_active(t[val]-1)
					setting = false
				end

			end

			y = y + 1
		end

		window:show_all()
	end,

	set = function(worker, id, data)
		local ss = worker.setter_list[id]
		if ss then
			for k, v in pairs(data.args) do
				local s = ss[k]
				if s then
					s(v)
				end
			end
		end
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


local function gui_main(worker)

	lgi = require "lgi"
	GLib, Gtk, Gdk = lgi.GLib, lgi.Gtk, lgi.Gdk

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


local function gui_start(gui)
	local s1, s2 = P.socketpair(P.AF_UNIX, P.SOCK_DGRAM, 0)
	gui.pid = P.fork()
	if gui.pid == 0 then
		for i = 3, 255 do
			if i ~= s2 then P.close(i) end
		end
		local worker = {
			fd = s2,
			window_list = {},
			setter_list = {},
		}
		gui_main(worker)
	end
	P.close(s2)
	gui.s = s1
	gui.gen_cache = {}

	watch_fd(s1, function()
		local code = P.recv(s1, 65535)
		local fn, err = load("return " .. code)
		if fn then
			local ok, msg = safecall(fn)
			if ok then
				if msg.cmd == "set" then
					local gen = gui.gen_cache[msg.genid]
					if gen then
						gen:set(msg.data)
					end
				end
			else
				logf(LG_WRN, "ipc error: %s", data)
			end
		else
			logf(LG_WRN, "ipc error: %s", err)
		end
	end)
end

--
-- Main process
--

local function gui_tx(gui, msg)
	P.send(gui.s, serialize(msg))
end


local function add(gui, gen)

	if not gui.pid then
		gui_start(gui)
	end

	local genid = tostring(math.random()):match("%.(.+)")
	gui.gen_cache[genid] = gen

	gui_tx(gui, { cmd = "add", genid = genid, data = { info = gen:info() }})
	gui_tx(gui, { cmd = "set", genid = genid, data = { args = gen:get() }})

end


local function add2(_, gen)


	window:show_all()
--	Gtk.main()
end



return {
   add = add,
}

-- vi: ft=lua ts=3 sw=3
