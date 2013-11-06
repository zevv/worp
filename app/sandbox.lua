
Sandbox = {}

local function sandbox_load(sandbox, code, name)
	local fn, err = load(code, name, "t", sandbox.env)
	if fn then
		local co = coroutine.create(fn)
		safecall(resumer(co))
	else
		print("Error: " .. fixup_error(err))
	end
end


local function sandbox_get(sandbox, name)
	return sandbox.env[name]
end


function Sandbox:new()

	local sandbox = {

		-- methods
		
		load = sandbox_load,
		get = sandbox_get,

		-- data

		env = {

		}
	}

	sandbox.env._ENV = sandbox.env

	autoload(sandbox.env, _G, "lib")

	return sandbox
end

-- vi: ft=lua ts=3 sw=3
