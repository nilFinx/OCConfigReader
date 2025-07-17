#!/usr/bin/env lua
if _VERSION == "Lua 5.1" then
	print "LuaJIT/5.1 is unsupported"
	os.exit(1)
end

if not arg[1] then
	print "OCConfigReader <path/to/config.plist>"
	os.exit(1)
end

local f = io.open(arg[1])
if not f then
	print "Failed to open file (Wrong path?)"
	os.exit(1)
end
local data = f:read("a")
f:close()

local plist = require "floxlist"(data)

local ssdts, drivers, kexts, tools, kextsarray, driversarray = {}, {}, {}, {}, {}, {}
local kextsshow = {normal = {}, plugin = {}, disabled = {}}
for _, v in pairs(plist.ACPI.Add) do
	local ssdtname = v.Path:match("(.+).aml")
	ssdts[ssdtname] = ssdtname
end

if type(plist.UEFI.Drivers[1]) == "string" then
	for _, v in pairs(plist.UEFI.Drivers) do
		local drvname = v:match("(.+).efi")
		drivers[drvname] = drvname
		table.insert(driversarray, drvname)
	end
else
	for _, v in pairs(plist.UEFI.Drivers) do
		local drvname = v.Path:match("(.+).efi")
		drivers[drvname] = drvname
		table.insert(driversarray, drvname)
	end
end

for _, v in pairs(plist.Kernel.Add) do
	local kextname = v.BundlePath:match "/?([-a-zA-Z0-9_]+).kext$"
	kexts[kextname] = v
	table.insert(kextsarray, kextname)
	table.insert(kextsshow[v.Enabled and (v.BundlePath:match("/") and "plugin" or "normal") or "disabled"], kextname)
end

for _, v in pairs(plist.Misc.Tools) do
	local toolname = v.Path:match("(.+).efi")
	tools[toolname] = toolname
end

local detections, order = table.unpack((require "detections"(plist, data, kexts, tools, drivers, ssdts, kextsshow, kextsarray, driversarray)))

local function load_plugin(name)
	if pcall(function() require(name) end) then
		require(name)(detections, order, plist, data, kexts, tools, drivers, ssdts, kextsshow, kextsarray, driversarray)
	end
end

load_plugin "plugin"
load_plugin "proppy"

for _, k in pairs(order) do
	local total, checked = 0, 0
	local v = detections[k]
	local text = ""
	local function prnt(t)
		text = text .. t .. "\n"
	end
	local function show(name, tbl)
		prnt(name..":")
		local ts = ""
		local i = 0
		for _, v in pairs(tbl) do
			i = i + 1
			ts = ts..v.." "
			if i >= 4 then
				prnt(ts)
				i = 0
				ts = ""
			end
		end
		if i ~= 0 then
			prnt(ts)
		end
		prnt("")
	end
	if k == "Info" then
		show("Kexts", kextsshow.normal)
		show("Kexts (plugin)", kextsshow.plugin)
		show("Kexts (disabled)", kextsshow.disabled)

		show("SSDTs", ssdts)

		show("Drivers", drivers)

		prnt("DeviceProperties: ")
		for k, v in pairs(plist.DeviceProperties.Add) do
			prnt(k)
			for l, w in pairs(v) do
				local symbol = " |"
				prnt(symbol..l..": "..tostring(w))
			end
		end
		text = text .. "\n"
	end
	for _, v in pairs(v) do
		local msg, check = v()
		if msg then
			text = text .. msg .. "\n"
			if check ~= false then
				checked = checked + 1
			end
		end
		if check ~= false and msg ~= false then
			total = total + 1
		end
	end
	print(("%s (%i/%i)"):format(k or "We Drive Drunk!", checked, total))
	print(text)
	if total == checked and k == "Autotool/prebuilt/configurator" then
		print "PERFECT PREBUILT - Triggered every single preb checks"
	end
end