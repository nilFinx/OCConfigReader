#!/usr/bin/env lua
local path = debug.getinfo(1).source:match("@?(.*[\\/])")
if path then 
	package.path = package.path .. ";" .. path .. "?.lua"
	path = path .. "/"
else
	path = ""
end
require "occr.occrstd"

asrt(_VERSION ~= "Lua 5.1", "LuaJIT/5.1 is unsupported")
asrt(arg[1], "OCConfigReader [smbios <SMBIOS>] <path/to/config.plist>")

local mode = ""

if arg[1] == "smbios" then
	asrt(arg[2], "No SMBIOS provided")
	mode = "smbios"
end

local f = io.open(arg[1])
asrt(f, "Failed to open file (Wrong path?)")
local data = f:read("a")
f:close()

local plist = require "occr.floxlist"(data)

local json = require "occr.json"
local f = io.open(path.."smbios.json")
asrt(f, "smbios.json is not found!") -- can be fixed?
sblist = json.decode(f:read("a"))
f:close()

plist.NVRAM.Add["7C"] = plist.NVRAM.Add["7C436110-AB2A-4BBB-A880-FE41995C9F82"] -- 7C exists now

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

local detections, order = table.unpack((require "occr.detections"(plist, data, kexts, tools, drivers, ssdts, kextsshow, kextsarray, driversarray)))

require "occr.acpi_patch"(detections, order, plist)

local function load_plugin(name)
	pcall(function()require("user."..name)(detections, order, plist, data, kexts, tools, drivers, ssdts, kextsshow, kextsarray, driversarray)end)
end

load_plugin "acpi_patch" -- Show ACPI patches

load_plugin "proppy" -- Proprietary checks

load_plugin "plugin" -- Default plugin name

---@diagnostic disable-next-line: param-type-mismatch
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
		local maxlen = 0
		for _, v in pairs(plist.DeviceProperties.Add) do
			for k in pairs(v) do
				if k:len() > maxlen then
					maxlen = k:len()
				end
			end
		end
		local space = "                                                                                  "
		for k, v in pairs(plist.DeviceProperties.Add) do
			prnt(k)
			for l, w in pairs(v) do
				local symbol = " |"
				prnt(symbol..l..space:sub(l:len(), maxlen).."| "..tostring(w))
			end
		end
		text = text .. "\n"
	end
	for _, v in pairs(v) do
		local suc, msg, check = pcall(v)
		if suc then
			if msg then
				text = text .. msg .. "\n"
				if check ~= false then
					checked = checked + 1
				end
			end
			if check ~= false and msg ~= false then
				total = total + 1
			end
		else
			print("\27[31mA check failed(please report!): " .. msg .. "\27[00m")
		end
	end
	print(("%s"..((total > 1) and " (%i/%i):" or ":")):format(k, checked, total))
	print(text)
end
