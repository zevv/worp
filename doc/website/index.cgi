#!/usr/bin/lua


print [[
Content-type: text/html

<!DOCTYPE html> 
<head>

<link rel="stylesheet" type="text/css" href="style.css">
<link rel="stylesheet" type="text/css" href="http://fonts.googleapis.com/css?family=Text Me One">
<link rel="icon" type="image/png" href="img/worp-icon.png" />



</head>

<body>

<div id=logo>
</div>

<div id=menu>
<a href=?main>main</a> 
| 
<a href=?architecture>architecture</a> 
| 
<a href=?concepts>concepts</a> 
| 
<a href=?jack>jack</a> 
| 
<a href=?dsp>dsp</a> 
| 
<a href=?examples>examples</a> 
</div>

<div id=main>
]]


local page = os.getenv("QUERY_STRING")
page = page:gsub("[^%w]", "")

local fd, err = io.open(page .. ".html")
if fd == nil then
	fd = io.open("main.html")
end
if fd then
	a = fd:read("*a")
	a = a:gsub("<div class=code>(.-)</div>", function(code)
		local fname = os.tmpname()
		local fd = io.open(fname, "w")
		fd:write(code)
		fd:close()

		local h = io.popen("highlight -f --inline-css --syntax lua " .. fname, "r")
		local v = h:read("*a")
		h:close()

		return "<div class=code>" .. v .. "</div>"
	end)
	print(a)
end

print [[
	</div>

</body>
]]

-- vi: ft=lua ts=3 sw=3


