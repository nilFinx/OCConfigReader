#!/usr/bin/env lua

if not (arg[1] and arg[2]) then
	print "parse <path/to/#smbios.txt> <out>"
	os.exit(1)
end

local f = io.open(arg[1])
if not f then
	print "Failed to open file (Wrong path?)"
	os.exit(1)
end
local data = f:read("a")
f:close()

local f = io.open(arg[2], "w")
if not f then
	print "Failed to open output file(Permission?)"
	os.exit(1)
end

local out = "[\n"
for v in data:gmatch("[^\n]+") do
	if v:sub(1, 1) ~= "-" and v:sub(1, 1) ~= " " then
		local t = {}
		for w in v:gmatch(" *([^|]+)|?") do
			table.insert(t, w:match("^%s*(.-)%s*$")) -- Exclude spaces
		end
		local year = t[4]:match("[S, ]*([0-9]+)/?[0-9]*$") -- Year, just year. Year please.
		out = out .. ('	["%s", "%s", "%s", "%s", "%s", "%s"],\n'):format(t[1], t[2], t[3], year, t[5]:match("[0-9]+[.][0-9x.]+"), t[5]:match("[.0-9x]+$"))
	end
end
out = out:sub(1, out:len()-2).."\n]"

f:write(out)
f:close()