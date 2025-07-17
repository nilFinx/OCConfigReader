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

local detectedamount = 0
local checkamount = 0
local textstack = ""
local sectionheader_default = "We Drive Drunk!"
local sectionheader = sectionheader_default

-- Append is true by default
local function check(text, append)
	if textstack ~= "" then
		textstack = textstack .. "\n"
	end
	textstack = textstack .. text
	if append ~= false then
		detectedamount = detectedamount + 1
	end
end

local function ck()
	checkamount = checkamount + 1
end

local function section(text)
	print(("%s (%i/%i)"):format(sectionheader, detectedamount, checkamount))
	sectionheader = (text ~= "" and text ~= nil) and text or sectionheader_default
	print(textstack)
	if textstack ~= "" then
		print ""
	end
	textstack = ""
	detectedamount = 0
	checkamount = 0
end

local bootarg = plist.NVRAM.Add["7C436110-AB2A-4BBB-A880-FE41995C9F82"]["boot-args"]
local ssdts = {}
local ssdtalt = {}
local drivers = {}
local driversalt = {}
local kexts = {}
local kextsalt = {}
local tools = {}
local toolsalt = {}

local kextsshow = {normal = {}, plugin = {}, disabled = {}}

local function _kitchensinked_internal(...)
	ck()
	local tocheck = {...}
	for k, v in pairs(tocheck) do
		local match = table.concat(kextsalt, " "):match(v)
		if not match then -- Allows rough match
			return
		end
		tocheck[k] = match -- Make sure to use the regex result
	end
	return tocheck
end

local function kitchensinked(...)
	local tocheck = _kitchensinked_internal(...)
	if tocheck then
		check(table.concat(tocheck, ", ").." are all present")
	end
end
local function kitchensinkedwithmsg(msg, ...) -- MONOSODIUM GLUTAMATE!!!
	local tocheck = _kitchensinked_internal(...)
	if tocheck then
		check(msg)
	end
end

for _, v in pairs(plist.ACPI.Add) do
	local ssdtname = v.Path:match("(.+).aml")
	ssdts[ssdtname] = true
	table.insert(ssdtalt, ssdtname)
end

if type(plist.UEFI.Drivers[1]) == "string" then
	for _, v in pairs(plist.UEFI.Drivers) do
		local drvname = v:match("(.+).efi")
		drivers[drvname] = true
		table.insert(driversalt, drvname)
	end
else
	for _, v in pairs(plist.UEFI.Drivers) do
		local drvname = v.Path:match("(.+).efi")
		drivers[drvname] = true
		table.insert(driversalt, drvname)
	end
end

for _, v in pairs(plist.Kernel.Add) do
	local kextname = v.BundlePath:match "/?([-a-zA-Z0-9_]+).kext$"
	kexts[kextname] = v
	table.insert(kextsalt, kextname)
	table.insert(kextsshow[v.Enabled and (v.BundlePath:match("/") and "plugin" or "normal") or "disabled"], kextname)
end

for _, v in pairs(plist.Misc.Tools) do
	local toolname = v.Path:match("(.+).efi")
	tools[toolname] = true
	table.insert(toolsalt, toolname)
end

print()

sectionheader = "Basic information" -- Info, nothing too bad

local function prnt(txt)
	check(txt or "", false)
end

local function show(name, tbl)
	prnt(name..":")
	for i = 1, #tbl, 4 do
		prnt(tbl[i].." "..(tbl[i+1] or "").." "..(tbl[i+2] or "").." "..(tbl[i+3] or ""))
	end
	prnt("")
end

show("Kexts", kextsshow.normal)
show("Kexts (plugin)", kextsshow.plugin)
show("Kexts (disabled)", kextsshow.disabled)

show("SSDTs", ssdtalt)

show("Drivers", driversalt)

show("Tools", toolsalt)

prnt("DeviceProperties: ")
for k, v in pairs(plist.DeviceProperties.Add) do
	prnt(k)
	for l, w in pairs(v) do
		local symbol = " |"
		prnt(symbol..l..": "..tostring(w))
	end
end
prnt()

check("SecureBootModel is "..plist.Misc.Security.SecureBootModel, false)
check("SMBIOS is "..plist.PlatformInfo.Generic.SystemProductName, false)
check("bootarg is "..plist.NVRAM.Add["7C436110-AB2A-4BBB-A880-FE41995C9F82"]["boot-args"], false)

ck()for _, v in pairs(plist.Kernel.Patch) do
	if v.Comment:match("AuthenticAMD") then
		check "This is an AMD machine"
		break
	end
end

ck()if bootarg:match("nvme=-1") then
	check "NVME is disabled"
end

ck()if bootarg:match("-[ri][ag][df]x?vesa") or bootarg:match("nv_disable=1") then -- Super awful, but this means igfx or rad
	check "One or more VESA arg is enabled"
end

ck()if drivers["OpenCanopy.efi"] then
	check "OpenCanopy is present (should be post-install stuff)"
end

ck() if plist.Kernel.Quirks.AppleXcpmCfgLock or plist.Kernel.Quirks.AppleCpuPmCfgLock then
	check "CFGLock is enabled"
end

ck() if plist.Kernel.Quirks.XhciPortLimit then
	check "XhciPortLimit is enabled(Catalina or older?)"
end

section("Mild oddities") -- Oddness/not advisable

local badkexts = {"USBPorts", "UTBDefault", "USBInjectAll", "(IO80211[a-zA-Z0-9]+) "}

local matches = {}
ck()for _, v in pairs(badkexts) do
	local match = table.concat(kextsalt, " "):match(v)
	if match then
		table.insert(matches, match)
	end
end
if matches[1] then
	check("Detected "..table.concat(matches, ", "))
end

ck()if #plist.Misc.Tools > 10 then
	check "More than 10 tools detected"
end

ck()if ssdts["SSDT-WIFI"] then
	check "SSDT-WIFI is present"
end

ck()if plist.NVRAM.Add["7C436110-AB2A-4BBB-A880-FE41995C9F82"]["csr-active-config"] == "030A0000" then
	check "SIP is disabled" -- Nobody would disable the entire SIP over filesystem and kext signing, and funny tool already uses weird value, so...
end

ck()if bootarg:match("-v$") or bootarg:match("-v ") then
	if not bootarg:match("keepsyms=1") then
		check "Verbose is enabled, but keepsyms is absent"
	end
	if not bootarg:match("debug=0x") and not plist.Kernel.Quirks.LapicKernelPanic then
		check "Verbose is enabled, but debug=0x argument nor LapicKernelPanic is present"
	end
end

ck()if bootarg:match("-no_compat_check") then
	check "SMBIOS compatibility check is disabled"
end

ck()if drivers.OpenHfsPlus then
	check "OpenHfsPlus is being used"
end

ck()if tools.CleanNvram then
	check "CleanNvram is being used"
end

section("Issues") -- Actual issues

ck()if #plist.UEFI.Drivers > 40 then
	check "More than 40 drivers detected"
end

ck()if table.concat(driversalt):match("Hfs.+Hfs") then
	check "More than 2 HFS+ drivers exists"
end

kitchensinked("IntelMausi", "IntelSnowMausi")
kitchensinked("AppleALC", "AppleALCU")
kitchensinked("WhateverGreen", "Noot[ed]*R[Xed]*") -- Hacky, but it detects both
kitchensinked("BrcmPatchRAM2", "BrcmPatchRAM3") -- Having those two already tells it well
kitchensinked("IntelBluetoothFirmware", "BrcmPatchRAM[1-3]?") -- If BrcmPatchRAM4 comes out, we will be doomed.
kitchensinked("BlueToolFixup", "[a-zA-Z]+BluetoothInjector") -- Show the full name
kitchensinked("AirportItlwm", " (Itlwm)") -- Messy, but at least it won't pickup AirportItlwm as Itlwm
kitchensinked("USBMap", "UTBMap")
kitchensinked("UTBMap", "UTBDefault")
---@diagnostic disable-next-line: deprecated
kitchensinkedwithmsg("All VirtualSMC plugins are there (but it can be normal)",
	"SMCProcessor", "SMCSuperIO", "SMCLightSensor", "SMCDellSensor", "SMCBatteryManager")
kitchensinkedwithmsg("All VoodooI2C plugins are present",
	"VoodooI2CAtmelMXT", "VoodooI2CELAN", "VoodooI2CFTE", "VoodooI2CHID", "VoodooI2CSynaptics")

local trigger = false
local hasutb = false
local hastoolbox = false
ck()for k in pairs(kexts) do -- I'll combine both as one check, as only one of them can trigger at a time.
	if k == "USBMap" or k == "UTBMap" or k == "USBPorts" or k == "UTBDefault" or k == "USBInjectAll" then
		if trigger then
			check "Two or more USB map Kexts detected"
			break
		end
		trigger = true
	end
end
ck()for k in pairs(kexts) do
	if k == "UTBMap" or k == "UTBDefault" then
		hasutb = true
	end
	if k == "USBToolBox" then
		hastoolbox = true
	end
end
if not trigger and not hastoolbox then
	check "USB maps not found"
end
if hasutb and not hastoolbox then
	check "UTBMap or UTBDefault exists, but USBToolBox is not there"
elseif hastoolbox and not trigger then
	check "USBToolBox exists, but maps aren't found(including bad maps)"
end

local platforminfo = plist.PlatformInfo.Generic
ck()if platforminfo.SystemProductName == "iMac19,1" and platforminfo.SystemSerialNumber:sub(1, 4) == "W000" then
	check "PlatformInfo is not set up"
end

local audiopath = plist.DeviceProperties.Add["PciRoot(0x0)/Pci(0x1b,0x0)"] or {}
ck()if audiopath["AAPL,ig-platform-id"] or audiopath["AAPL,snb-platform-id"] or audiopath["framebuffer-patch-enable"] then
	check "iGPU properties are injected to audio device"
end

local igpupath = plist.DeviceProperties.Add["PciRoot(0x0)/Pci(0x2,0x0)"] or {}
ck()if #igpupath > 15 then
	check "iGPU properties are bloated"
end

ck()if kexts.Lilu.Comment == "Patch engine" and kexts.Lilu.MinKernel == "8.0.0" then
	check "OC Clean Snapshot or configurator equivalent is not done"
end

ck()if ssdts["SSDT-EC"] then
	for k in pairs(ssdts) do
		if k:sub(1,8) == "SSDT-EC-" then
			check "SSDTTime SSDT-EC is present, but prebuilt SSDT-EC is also present" break
		end
	end
end

ck()if not (kexts.VirtualSMC and kexts.VirtualSMC.Enabled) then
	check("VirtualSMC is "..(kexts.VirtualSMC and "disabled" or "absent"))
end

ck()if ssdts.APIC and ssdts.DMAR and ssdts.SSDT1 and ssdts.SSDT then
	check "Machine's ACPI tables are being injected"
end

ck()for k in pairs(plist.DeviceProperties) do
	if k ~= "Add" and k ~= "Delete" and k:sub(1,1) ~= "#" then
		check(k.." is found in DeviceProperties, outside of Add/Delete")
		break
	end
end

section("Autotool/prebuilt/configurator") -- Prebuilt/autotool/configurator

ck()for _, v in pairs(plist.Kernel.Add) do
	if v.Arch == "x86_64" then
		check "One or more Kext arch is set to x86_64" break
	end
end

ck()if string.match(data, "<data>[	 \n]+[a-zA-Z0-9=+/]+[ 	\n]+</data>") then
	check "Detected <data> with newline/whitespaces before </data> (can be enabled with ProperTree's option)"
end

-- Thanks CorpNewt! -- DEAD: Thanks shitlify dev!
--[[if plist.Misc.Boot.Timeout == 10 and plist.Misc.Debug.Target == 0 and plist.Misc.Boot.PickerMode == "External" 
	and plist.NVRAM.Add["7C436110-AB2A-4BBB-A880-FE41995C9F82"]["prev-lang:kbd"] == "en:252" then
	check "Failed specific autotool detection"
end]]

-- I will nuke israel if they patched this
ck()if plist.Misc.Boot.PickerMode == "External" and plist.Misc.Boot.PickerVariant == "Auto" then
	check "Failed specific autotool detection (V2)"
end

ck()if type(plist.UEFI.Drivers[1]) == "string" then
	check "OpenCore is outdated(old Drivers schema)"
end

ck()for _, v in pairs(kexts) do
	if v.Comment:match("V[0-9.]+") then
		check "One or more Kext comment has a version" break
	end
end

ck()for _, v in pairs(kexts) do
	if v.Comment == "" then
		check "One or more Kext comment is empty" break
	end
end

ck()if ssdts["MaLd0n"] then
	check "MaLd0n.aml is present"
end

if plist.ACPI.Quirks.RebaseRegions then         -- https://www.insanelymac.com/forum/topic/352881-when-is-rebaseregions-necessary/#findComment-2790821
	check("The user is a porno pro", false)     -- Don't need this quirk = Porno Amateur
end 									        -- Need this quirk = Porno Pro 

if table.concat(driversalt, ""):match("AptioFix2Drv") then -- Joke detection, it doesn't count towards the total detection
	check("AptioFix detected", false) -- What the fuck did you just fucking say about me, you little bitch? I'll have you know I graduated top of my class in the r/hackintosh Academy, and I've been involved in numerous secret raids on Tonymacx86, and I have over 300 confirmed roasts. I am trained in OsxAptioFix2Drv-free2000 warfare and I'm the top Hackintosher in the entire InsanelyMac armed forces. You are nothing to me but just another UniBeast user. I will wipe you the fuck out with precision the likes of which has never been seen before on this server, mark my fucking words. You think you can get away with saying that shit to me over the Internet? Think again, fucker. As we speak I am contacting my secret network of slavs across the former Soviet Union and your IP is being traced right now so you better prepare for the storm, maggot. The storm that wipes out the pathetic little thing you call your life. You're fucking dead, kid. I can be anywhere, anytime, and I can delete you in over seven hundred ways, and that's just with my Snow Leopard install. Not only am I extensively trained in unarmed macOS installs, but I have access to the entire arsenal of the Acidanthera repo and I will use it to its full extent to wipe your miserable ass off the face of the continent, you little shit. If only you could have known what unholy retribution your little “clover isn’t that bad” comment was about to bring down upon you, maybe you would have held your fucking tongue. But you couldn't, you didn't, and now you're paying the price, you goddamn idiot. I will shit fury all over you and you will drown in it. You're fucking dead, kiddo.
end

if detectedamount == checkamount then
	check("PERFECT PREBUILT - Triggered every single preb checks", false)
end
section()
