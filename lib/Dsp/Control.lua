
function Dsp:Control(def, mod)

	local control = {

		-- methods

		get = function(control)
			return control.value
		end,
		
		set = function(control, value, update)
			if control.type == "enum" and type(value) == "number" then
				value = control.options[math.floor(value + 0.5)]
			end
			if value ~= nil then
				control.value = value
				for fn in pairs(control.fn_set) do
					fn(value)
				end
				if update ~= false then
					mod:update()
				end
			end
		end,

		set_uni = function(control, v, update)
			if control.min and control.max then
				v = control.min + v * (control.max-control.min)
				if control.log then v = (control.max+1) ^ (v/control.max) - 1 end
				control:set(v)
			end
		end,

		on_set = function(control, fn)
			control.fn_set[fn] = true
		end,

		-- data
	
		id = def.id or "",
		description = def.description or "",
		type = def.type or "number",
		fmt = def.fmt,
		min = def.min or 0,
		max = def.max or 1,
		options = def.options or {},
		log = def.log,
		unit = def.unit,
		default = def.default,
		value = nil,
		fn_set = {},
	}

	if def.type == "enum" then
		control.min, control.max = 1, #def.options
	end

	setmetatable(control, {
		__tostring = function()
			return "control:%s(%s)" % { control.id, control.value }
		end
	})

	if def.fn_set then
		control:on_set(def.fn_set)
	end
	control:set(def.default, false)

	return control

end


function Dsp:Mod(def, init)

	local mod = {

		-- methods
		
		update = function(mod)
			if def.controls.fn_update then
				def.controls.fn_update()
			end
		end,

		set = function(mod, id, value)
			if type(id) == "table" then
				for id, value in pairs(id) do
					mod:control(id):set(value, false)
				end
				mod:update()
			else
				mod:control(id):set(value)
			end
		end,

		controls = function(mod)
			return mod.control_list
		end,

		get = function(mod)
			return mod
		end,

		control = function(mod, id)
			return mod.control_list[id]
		end,

		help = function(mod)
			print(mod.description)
			for _, control in ipairs(mod:controls()) do
				print(" - %s: %s (%s)" % { control.id, control.description, control.unit or "" })
			end
		end,

		-- data

		id = def.id,
		description = def.description,
		control_list = {}
	}
	
	setmetatable(mod, {
		__tostring = function()
			return "Generator:%s" % { def.id }
		end,
		__call = function(_, ...)
			return def.fn_gen(mod, ...)
		end,
	})

	for i, def in ipairs(def.controls) do
		local control = Dsp:Control(def, mod)
		mod.control_list[i] = control
		mod.control_list[control.id] = control
		if init then
			control:set(init[control.id], false)
		end
	end

	mod:update()

	return mod
end

-- vi: ft=lua ts=3 sw=3
