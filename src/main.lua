#!/usr/bin/env lua
local path = debug.getinfo(1).source:match("@?(.*[\\/])")
if path then 
	package.path = package.path .. ";" .. path .. "?.lua"
	path = path .. "/"
else
	path = ""
end

local function error(msg)
	print(msg)
	os.exit(1)
end

local function assert(cond, msg)
	if not cond then
		error(msg)
	end
end

assert(_VERSION ~= "Lua 5.1", "LuaJIT/5.1 is unsupported")
assert(arg[1], "OCConfigReader <smbios or path/to/config.plist>")

-- AaBcDeF1234,1
if arg[1]:match("^%u%S+%d+,%d$") then
	local smbios = require "smbios"[arg[1]]
	---@class smbios
	local formatted = {
		codename = smbios[1],
		gpu = smbios[2],
		year = smbios[3],
		min = smbios[4],
		max = smbios[5]
	}
	print("Codename: ", formatted.codename)
	print("Year: ", formatted.year)
	local osname = require "util".osxname
	print("Minimum OS version: ", osname(formatted.min))
	print("Maximum OS version: ", osname(formatted.max))
	os.exit(0)
end

occr = require "init"

local f = io.open(arg[1])
assert(f, "Failed to open file (Wrong path?)")
local data = f:read("a")
f:close()

local returns, data = occr.run(data)
local function show(name, tbl)
	local ts = ""
	local i = 0
	if next(tbl) then
		print(name..":")
		for k in pairs(tbl) do
			i = i + 1
			ts = ts..k.."  "
			if i >= 4 then
				print("  "..ts)
				i = 0
				ts = ""
			end
		end
		if i ~= 0 then
			print("  "..ts)
		end
		print("")
	end
end

show("Kexts", data.kexts.normal)
show("Kexts (plugin)", data.kexts.plugin)
show("Kexts (disabled)", data.kexts.disabled.normal)
show("Kexts (disabled plugins)", data.kexts.disabled.plugin)

show("SSDTs", data.ssdts.enabled)
show("SSDTs (disabled)", data.ssdts.disabled)

show("Drivers", data.drivers.enabled)
show("Drivers (disabled)", data.drivers.disabled)

local maxlen = 0
for _, v in pairs(data.plist.DeviceProperties.Add) do
	for k in pairs(v) do
		if k:len() > maxlen then
			maxlen = k:len()
		end
	end
end
if next(data.plist.DeviceProperties.Add) then
	print "DeviceProperties:"
	for k, v in pairs(data.plist.DeviceProperties.Add) do
		print("  "..k)
		for l, w in pairs(v) do
			local symbol = "   |"
			print(symbol..l..string.rep(" ", (maxlen - l:len())).."| "..tostring(w))
		end
	end
	print("")
end

for _, k in pairs(returns.order) do
	local t = returns.result[k]
	if next(t.result) then
		print(("%s (%d/%d):"):format(k, t.checked, t.total))
		for _, v in pairs(t.result) do
			print(" "..v)
		end
		print("")
	end
end

if #returns.errormsges ~= 0 then
	print "\27[33mWarning:"
	print(returns.errormsges.."\27[00m")
end