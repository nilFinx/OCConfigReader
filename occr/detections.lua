-- Each detections should return comment(nil if failed check), and count(true by default).
local runme = function(plist, raw, kexts, tools, drivers, ssdts, kextsshow, kextsarray, driversarray)

local function _kitchensinked(tocheck)
	local kextstr = table.concat(kextsarray, " ")
	local checked = {}
	for _, v in pairs(tocheck) do
		local m = kextstr:match(v)
		if not m then
			return
		end
		table.insert(checked, m)
	end
	return table.concat(checked, ", ").." are all present"
end



local trigger = false -- Reserved by two checks
local bootarg = plist.NVRAM.Add["7C"]["boot-args"]
local verbosed = bootarg:match("-v$") or bootarg:find("-v ")
local minver = 10.4 -- 10.3 intel port :fire:
local maxver = 26 -- 27 wen eta??

local function _maxset(v)
	if v <= maxver then
		maxver = v
	end
end

local function _minset(v)
	if v >= minver then
		minver = v
	end
end

local order = {"Info", "Oddities", "Issues", "Kitchen sinked", "Autotool/prebuilt/configurator", "Assumed version"}
local d = {
	Info = {
		function() -- Tiny bit messy, but it *works*
			local smbios = plist.PlatformInfo.Generic.SystemProductName
			local sbdata = sblist[smbios]
			---@diagnostic disable-next-line: cast-local-type
			minver = tonumber(sbdata[4]:match("[0-9]+[.][0-9]+") or sbdata[4]:match("[0-9]+"))
			---@diagnostic disable-next-line: cast-local-type
			maxver = tonumber(sbdata[5]:match("[0-9]+[.][0-9]+") or sbdata[5]:match("[0-9]+"))
			return ("SMBIOS is %s, %s to %s (%s)"):format(smbios, sbdata[4], sbdata[5], sbdata[1]).."\n"..
				"bootarg is "..bootarg.."\n"..
				"SecureBootModel is "..plist.Misc.Security.SecureBootModel,
				false
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
			if drivers["OpenCanopy"] then
				return "OpenCanopy is present (should be post-install stuff)"
			end
		end,
		function()
			if plist.Kernel.Quirks.AppleXcpmCfgLock or plist.Kernel.Quirks.AppleCpuPmCfgLock then
				return "CFGLock is enabled"
			end
		end,
		function()
			if plist.Kernel.Quirks.XhciPortLimit then
				_maxset(10.15)
				return "XhciPortLimit is enabled(Catalina or older?)"
			end
		end
	},
	Oddities = {
		function()
			if tools.CleanNvram then
				return "CleanNvram is being used"
			end
		end,
		function()
			if drivers.OpenHfsPlus then
				return "OpenHfsPlus is being used"
			end
		end,
		function()
			local badkexts = {"USBPorts", "UTBDefault", "USBInjectAll", "(IO80211[a-zA-Z0-9]+) "}
			local matches = {}
			for _, v in pairs(badkexts) do
				local match = table.concat(kextsarray, " "):match(v)
				if match then
					table.insert(matches, match)
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
			if ssdts["SSDT-EC"] then
				for k in pairs(ssdts) do
					if k:sub(1,8) == "SSDT-EC-" then
						return "SSDTTime SSDT-EC is present, but prebuilt SSDT-EC is also present"
					end
				end
			end
		end,
		function()
			if kexts.Lilu.Comment == "Patch engine" and kexts.Lilu.MinKernel == "8.0.0" then
				return "OC Clean Snapshot or configurator equivalent is not done"
			end
		end,
		function()
			if #(plist.DeviceProperties.Add["PciRoot(0x0)/Pci(0x2,0x0)"] or {}) > 15 then
				return "iGPU properties are bloated"
			end
		end,
		function()
			local audiopath = plist.DeviceProperties.Add["PciRoot(0x0)/Pci(0x1b,0x0)"] or {}
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
			if table.concat(driversarray):find("Hfs.+Hfs") then
				return "More than 2 HFS+ drivers exists"
			elseif not table.concat(driversarray):find("Hfs") then
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
			if ssdts.APIC and ssdts.DMAR and ssdts.SSDT1 and ssdts.SSDT then
				return "Machine's ACPI tables are being injected"
			end
		end,
		function()
			if not (kexts.VirtualSMC and kexts.VirtualSMC.Enabled) then
				return "VirtualSMC is "..(kexts.VirtualSMC and "disabled" or "absent")
			end	
		end,
		function()
			for k in pairs(kexts) do
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
			for k in pairs(kexts) do
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
		end
	},
	["Kitchen sinked"] = {}, -- reserved
	["Autotool/prebuilt/configurator"] = {
		function() -- Thanks CorpNewt! -- DEAD: Thanks shitlify dev!
			if plist.Misc.Boot.Timeout == 10 and plist.Misc.Debug.Target == 0 and plist.Misc.Boot.PickerMode == "External" 
				and plist.NVRAM.Add["7C"]["prev-lang:kbd"] == "en:252" then
				return "Failed specific autotool detection (V1, if you believe this config.plist is generated with latest tool, make an issue)"
			end
			return false -- This should not even trigger nowadays
		end,
		function()
			if type(plist.UEFI.Drivers[1]) == "string" then
				return "OpenCore is outdated(old Drivers schema)"
			end
		end,
		function()
			for _, v in pairs(kexts) do
				if v.Comment:match("V[0-9.]+") then
					return "One or more Kext comment has a version"
				end
			end
		end,
		function()
			for _, v in pairs(kexts) do
				if v.Comment == "" then
					return "One or more Kext comment is empty"
				end
			end
		end,
		function()
			if ssdts["MaLd0n"] then
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
			if table.concat(drivers, ""):find("AptioFix2Drv") then
				return "AptioFix detected", false -- What the fuck did you just fucking say about me, you little bitch? I'll have you know I graduated top of my class in the r/hackintosh Academy, and I've been involved in numerous secret raids on Tonymacx86, and I have over 300 confirmed roasts. I am trained in OsxAptioFix2Drv-free2000 warfare and I'm the top Hackintosher in the entire InsanelyMac armed forces. You are nothing to me but just another UniBeast user. I will wipe you the fuck out with precision the likes of which has never been seen before on this server, mark my fucking words. You think you can get away with saying that shit to me over the Internet? Think again, fucker. As we speak I am contacting my secret network of slavs across the former Soviet Union and your IP is being traced right now so you better prepare for the storm, maggot. The storm that wipes out the pathetic little thing you call your life. You're fucking dead, kid. I can be anywhere, anytime, and I can delete you in over seven hundred ways, and that's just with my Snow Leopard install. Not only am I extensively trained in unarmed macOS installs, but I have access to the entire arsenal of the Acidanthera repo and I will use it to its full extent to wipe your miserable ass off the face of the continent, you little shit. If only you could have known what unholy retribution your little “clover isn’t that bad” comment was about to bring down upon you, maybe you would have held your fucking tongue. But you couldn't, you didn't, and now you're paying the price, you goddamn idiot. I will shit fury all over you and you will drown in it. You're fucking dead, kiddo.
			end
			return false
		end
	},
	["Assumed version"] = {
		function() -- Assumption fever!!!
			if kexts["BrcmPatchRAM3"] then
				_minset(10.15)
			elseif kexts["BrcmPatchRAM2"] then
				_minset(10.11)
				_maxset(10.14)
			elseif kexts["BrcmPatchRAM"] then
				_maxset(10.10)
			end

			if kexts["BlueToolFixup"] then
				_minset(12)
			elseif table.concat(kextsarray, " "):find("BluetoothInjector") then
				_maxset(11)
			end

			if kexts["SMCAMDProcessor"] then
				_minset(10.13)
			end

			if kexts["SMCRadeonSensors"] then
				_minset(10.14)
			end

			if kexts["AppleIGB"] then
				_minset(12)
			end

			if bootarg:find("e1000=0") then
				_minset(12)
			elseif bootarg:find("dk[.]e1000=0") then
				_maxset(11)
			end
		
			return false -- No counting
		end,
		function()
			if minver > maxver then
				return "Failed to assume(Overlap?)"
			elseif minver == maxver then
				return "Running "..osxname(minver)
			else
				return ("Running %s to %s"):format(osxname(minver), osxname(maxver))
			end
		end
	}
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
kitchensinked("WhateverGreen", "Noot[ed]*R[Xed]+") -- Hacky, but it detects both
kitchensinked("IntelBluetoothFirmware", "BrcmPatchRAM[1-3]?") -- If BrcmPatchRAM4 comes out, we will be doomed.
kitchensinked("BlueToolFixup", "[a-zA-Z]+BluetoothInjector") -- Show the full name
kitchensinked("AirportItlwm", " (Itlwm)") -- Messy, but at least it won't pickup AirportItlwm as Itlwm
kitchensinked("USBMap", "UTBMap")
kitchensinked("UTBMap", "UTBDefault")

kitchensinkedwithmsg("All VirtualSMC plugins are there (but it can be normal)",
	"SMCProcessor", "SMCSuperIO", "SMCLightSensor", "SMCDellSensor", "SMCBatteryManager")
kitchensinkedwithmsg("All VoodooI2C plugins are present",
	"VoodooI2CAtmelMXT", "VoodooI2CELAN", "VoodooI2CFTE", "VoodooI2CHID", "VoodooI2CSynaptics")


return {d, order} -- Workaround to being only able to pass 1 arguments
end
return runme