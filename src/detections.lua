-- Each detections should return comment(nil if failed check), and count(true by default).
local runme = function(args)
local plist = args.plist
local kxts = args.kexts -- Sorry for this. I had to do it for refactor.
local tls = args.tools
local drvs = args.drivers
local sdts = args.ssdts
local function _kitchensinked(tocheck)
	local checked = {}
	for _, v in pairs(tocheck) do
		if not kxts.has[v] then
			return
		end
		table.insert(checked, v)
	end
	local last = checked[#checked]
	table.remove(checked, #checked)
	return table.concat(checked, ", ").."and "..last.." are all present"
end

local trigger = false -- Reserved by two checks
local bootarg = plist.NVRAM.Add["7C"]["boot-args"] or ""
local verbosed = bootarg:match("-v$") or bootarg:find("-v ")
local d = {
	Info = {
		function() -- Tiny bit messy, but it *works*
			local smbios = plist.PlatformInfo.Generic.SystemProductName
			local sbdata = args.sblist[smbios]
			return ("SMBIOS is %s, %s to %s (%s)"):format(smbios, sbdata[4], sbdata[5], sbdata[1])
		end,
		function()
			return "bootarg is "..bootarg, false
		end,
		function()
			return "SecureBootModel is "..plist.Misc.Security.SecureBootModel, false
		end,
		function()
			for _, v in pairs(plist.Kernel.Patch) do
				if v.Comment:match("AuthenticAMD") then
					return "This is an AMD machine"
				end
			end
		end,
		function()
			if bootarg:find("nvme=[-]1") then -- heckin regex
				return "NVME is disabled"
			end
		end,
		function()   -- Super awful, but this means igfx or rad
			if bootarg:find("-[ri][ag][df]x?vesa") or bootarg:find("nv_disable=1") or bootarg:find("-amd_no_dgpu_accel") then
				return "One or more VESA arg is enabled"                              -- include macOS official arg for AMD
			end      -- Just works. One function call.
		end,
		function()
			if plist.Misc.Boot.PickerMode ~= "Builtin" then
				return "PickerMode is "..plist.Misc.Boot.PickerMode
			end
		end,
		function()
			if plist.Kernel.Quirks.AppleXcpmCfgLock or plist.Kernel.Quirks.AppleCpuPmCfgLock then
				return "CFGLock is enabled"
			end
		end,
		function()
			if plist.Kernel.Quirks.XhciPortLimit then
				return "XhciPortLimit is enabled(Catalina or older?)"
			end
		end,
		function()
			if drvs.has "OpenVariableRuntimeDxe" then
				return "OpenVariableRuntimeDxe exists (only for UEFI systems)"
			end
		end,
		function()
			if drvs.has "OpenPartitionDxe" then
				return "OpenPartitionDxe exists (only for UEFI systems)"
			end
		end
	},
	Oddities = {
		function()
			if tls.has "CleanNvram" then
				return "CleanNvram is being used"
			end
		end,
		function()
			if drvs.has "OpenHfsPlus" then
				return "OpenHfsPlus is being used"
			end
		end,
		function()
			local badkexts = {"USBPorts", "UTBDefault", "USBInjectAll", "(IO80211[a-zA-Z0-9]+) "}
			local matches = {}
			for _, v in pairs(badkexts) do
				local match = kxts.has[v]
				if match then
					table.insert(matches, v)
				end
			end
			if matches[1] then
				return "Detected "..table.concat(matches, ", ")
			end
		end,
		function()
			if plist.NVRAM.Add["7C"]["csr-active-config"] == "030A0000" then
				return "SIP is disabled" -- Nobody would disable the entire SIP over filesystem and kext signing, so...
			end
		end,
		function()
			if #plist.Misc.Tools > 10 then
				return "More than 10 tools detected"
			end
		end,
		function()
			if bootarg:find("-no_compat_check") then
				return "SMBIOS compatibility check is disabled"
			end
		end,
		function()
			if verbosed then
				if not bootarg:find("debug=0x") and not plist.Kernel.Quirks.LapicKernelPanic then
					return "Verbose is enabled, but debug=0x argument nor LapicKernelPanic is present"
				end
			end
		end,
		function()
			if verbosed then
				if not bootarg:find("keepsyms=1") then
					return "Verbose is enabled, but keepsyms is absent"
				end
			end
		end
	},
	Issues = {
		function()
			if sdts.has "SSDT-EC" then
				for k in pairs(sdts.enabled) do
					if k:sub(1,8) == "SSDT-EC-" then
						return "SSDTTime SSDT-EC is present, but prebuilt SSDT-EC is also present"
					end
				end
			end
		end,
		function()
			if kxts.normal.Lilu.Comment == "Patch engine" and kxts.normal.Lilu.MinKernel == "8.0.0" then
				return "OC Clean Snapshot or configurator equivalent is not done"
			end
		end,
		function()
			if #(plist.DeviceProperties.Add["PciRoot(0x0)/Pci(0x2,0x0)"] or {}) > 15 then
				return "iGPU properties are bloated"
			end
		end,
		function()
			local audiopath = rawget(plist.DeviceProperties.Add, "PciRoot(0x0)/Pci(0x1b,0x0)") or {}
			if audiopath["AAPL,ig-platform-id"] or audiopath["AAPL,snb-platform-id"] or audiopath["framebuffer-patch-enable"] then
				return "iGPU properties are injected to audio device"
			end
		end,
		function()
			for k in pairs(plist.DeviceProperties) do
				if k ~= "Add" and k ~= "Delete" and k:sub(1,1) ~= "#" then
					return (k.." is found in DeviceProperties, outside of Add/Delete")
				end
			end
		end,
		function()
			if #plist.UEFI.Drivers > 40 then
				return "More than 40 drivers detected"
			end
		end,
		function()
			if table.concat(drvs.enabled):find("Hfs.+Hfs") then
				return "More than 2 HFS+ drivers exists"
			elseif not table.concat(drvs.enabled):find("Hfs") then
				return "HFS+ driver is missing"
			end
		end,
		function()
			local platforminfo = plist.PlatformInfo.Generic
			if platforminfo.SystemProductName == "iMac19,1" and platforminfo.SystemSerialNumber:sub(1, 4) == "W000" then
				return "PlatformInfo is not set up"
			end
		end,
		function()
			if sdts.has.APIC and sdts.has.DMAR and sdts.has.SSDT1 and sdts.has.SSDT then
				return "Machine's ACPI tables are being injected"
			end
		end,
		function()
			if not kxts.normal.VirtualSMC then
				return "VirtualSMC is "..(kxts.has.VirtualSMC and "disabled" or "absent")
			end	
		end,
		function()
			for k in pairs(kxts.normal) do
				if k == "USBMap" or k == "UTBMap" or k == "USBPorts" or k == "UTBDefault" or k == "USBInjectAll" then
					if trigger then
						return "Two or more USB map Kexts detected"
					end
					trigger = true
				end
			end
		end,
		function()
			local hasutb = false
			local hastoolbox = false
			for k in pairs(kxts.normal) do
				if k == "UTBMap" or k == "UTBDefault" then
					hasutb = true
				end
				if k == "USBToolBox" then
					hastoolbox = true
				end
			end
			if not trigger and not hastoolbox then
				return "USB maps not found"
			end
			if hasutb and not hastoolbox then
				return "UTBMap or UTBDefault exists, but USBToolBox is not there"
			elseif hastoolbox and not trigger then
				return "USBToolBox exists, but maps aren't found(including bad maps)"
			end
		end,
		function()
			local a, b, c = plist.Booter.Quirks.EnableWriteUnprotector,
				plist.Booter.Quirks.RebuildAppleMemoryMap,
				plist.Booter.Quirks.SyncRuntimePermissions
			if a and b and c then -- I covered all combos right
				return "All 3 MATs related Booter quirks are enabled"
			end
			if not (a or b or c) then
				return "All 3 MATs related Booter quirks are disabled"
			end
			if not ((b and c and not a) or (a and not (b or c))) then
				return "Invalid MATs related Booter quirks combination"
			end
		end
	},
	["Kitchen sinked"] = {}, -- reserved
	["Autotool/prebuilt/configurator"] = {
		function()
			if type(plist.UEFI.Drivers[1]) == "string" then
				return "OpenCore is outdated(old Drivers schema)"
			end
		end,
		function()
			for _, v in pairs(kxts.normal) do
				if v.Comment then
					if v.Comment:match("V[0-9.]+") then
						return "One or more Kext comment has a version"
					end
				else
					return "One Kext literally does not have the version"
				end
			end
		end,
		function()
			for _, v in pairs(kxts.normal) do
				if v.Comment then
					if v.Comment == "" then
						return "One or more Kext comment is empty"
					end
				end
			end
		end,
		function()
			if sdts["MaLd0n"] then
				return "The EFI got a blessing by real MaLd0n", false
			end
			return false
		end,
		function()
			if plist.ACPI.Quirks.RebaseRegions then         -- https://www.insanelymac.com/forum/topic/352881-when-is-rebaseregions-necessary/#findComment-2790821
				return "The user is a porno pro", false     -- Don't need this quirk = Porno Amateur
			end 									        -- Need this quirk = Porno Pro 
			return false
		end,
		function()
			if table.concat(drvs, ""):find("AptioFix2Drv") then
				return "AptioFix2Drv detected", false -- What the fuck did you just fucking say about me, you little bitch? I'll have you know I graduated top of my class in the r/hackintosh Academy, and I've been involved in numerous secret raids on Tonymacx86, and I have over 300 confirmed roasts. I am trained in OsxAptioFix2Drv-free2000 warfare and I'm the top Hackintosher in the entire InsanelyMac armed forces. You are nothing to me but just another UniBeast user. I will wipe you the fuck out with precision the likes of which has never been seen before on this server, mark my fucking words. You think you can get away with saying that shit to me over the Internet? Think again, fucker. As we speak I am contacting my secret network of slavs across the former Soviet Union and your IP is being traced right now so you better prepare for the storm, maggot. The storm that wipes out the pathetic little thing you call your life. You're fucking dead, kid. I can be anywhere, anytime, and I can delete you in over seven hundred ways, and that's just with my Snow Leopard install. Not only am I extensively trained in unarmed macOS installs, but I have access to the entire arsenal of the Acidanthera repo and I will use it to its full extent to wipe your miserable ass off the face of the continent, you little shit. If only you could have known what unholy retribution your little “clover isn’t that bad” comment was about to bring down upon you, maybe you would have held your fucking tongue. But you couldn't, you didn't, and now you're paying the price, you goddamn idiot. I will shit fury all over you and you will drown in it. You're fucking dead, kiddo.
			end
			return false
		end
	},
}

local function kitchensinked(...)
	local stuff = {...}
	table.insert(d["Kitchen sinked"], function() return _kitchensinked(stuff) end)
end
local function kitchensinkedwithmsg(msg, ...)
	local stuff = {...}
	table.insert(d["Kitchen sinked"], function() return _kitchensinked(stuff) and msg or nil end)
end

kitchensinked("IntelMausi", "IntelSnowMausi")
kitchensinked("AppleALC", "AppleALCU")
kitchensinked("BrcmPatchRAM2", "BrcmPatchRAM3") -- Having those two already tells it well
kitchensinked("WhateverGreen", "NootedRed")
kitchensinked("WhateverGreen", "NootRX")
kitchensinked("IntelBluetoothFirmware", "BrcmPatchRAM1")
kitchensinked("IntelBluetoothFirmware", "BrcmPatchRAM2")
kitchensinked("IntelBluetoothFirmware", "BrcmPatchRAM3") -- If BrcmPatchRAM4 comes out, we will be doomed.
kitchensinked("BlueToolFixup", "IntelBluetoothInjector")
kitchensinked("AirportItlwm", " Itlwm")
kitchensinked("USBMap", "UTBMap")
kitchensinked("UTBMap", "UTBDefault")
kitchensinked("USBMap", "UTBDefault")

kitchensinkedwithmsg("All VirtualSMC plugins are there (but it can be normal)",
	"SMCProcessor", "SMCSuperIO", "SMCLightSensor", "SMCDellSensor", "SMCBatteryManager")
kitchensinkedwithmsg("All VoodooI2C plugins are present",
	"VoodooI2CAtmelMXT", "VoodooI2CELAN", "VoodooI2CFTE", "VoodooI2CHID", "VoodooI2CSynaptics")


return d
end

return {runme, {"Info", "Oddities", "Issues", "Kitchen sinked", "Autotool/prebuilt/configurator"}}
