

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
			print("%s:" % { mod.description })
			for _, control in ipairs(mod:controls()) do
				local range = ""
				if #control.options > 0 then
					range = table.concat(control.options, "/")
				elseif control.min or control.max then
					range = "%s..%s" % { control.min or 0, control.max or 1 }
				end
				print(" - %s: %s (%s)" % { control.id, control.description, range })
			end
		end,

		-- data

		id = def.id,
		description = def.description,
		control_list = {}
	}
	
	setmetatable(mod, {
		__tostring = function()
			return "mod:%s" % { def.description }
		end,
		__call = function(_, ...)
			return def.fn_gen(...)
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
