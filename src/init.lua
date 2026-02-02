local occr = {}
local missing = {}
local util = require "util"
local sblist = require "smbios"
local floxlist = require "floxlist"
local defaultdectsloader = require "detections"

local mashprinted = {}
local sf
sf = function(t, k, pureset)
	local mt = {
		__index = sf,
		__call = function() return "" end,
		_k = {}
	}
	local uk = (getmetatable(t) or {})._k
	if uk then 
		for _, v in pairs(uk) do
			table.insert(mt._k, v)
		end
	end
	if k then
		table.insert(mt._k, k)
	end
	if not pureset then
		local mash = table.concat(mt._k, ".") or k
		mash = mash ~= "" and mash or k
		if mash and mash ~= "" and not mashprinted[mash] then
			table.insert(missing, mash)
			mashprinted[mash] = true
		end
	end
	local o = setmetatable(pureset and t or {}, mt)
	if not pureset then rawset(t, k, o) end

	return o
end


local mtblapply -- This is necessary. Really.
function mtblapply(t, k)
	sf(t, k, true)
	for k, v in pairs(t) do
		if type(v) == "table" then
			mtblapply(v, k)
		end
	end
end

local pllist = {}

local function load_plugin(name)
	local suc, fun = pcall(function() return require(""..name) end)
	if suc then table.insert(pllist, fun) end
end

load_plugin "acpi_patch" -- Show ACPI patches

load_plugin "proppy" -- Proprietary checks

load_plugin "plugin" -- Default plugin name

function occr.run(rawplist)
local plist = floxlist(rawplist)
mtblapply(plist)

---@deprecated Use util.SevenC
plist.NVRAM.Add["7C"] = plist.NVRAM.Add[util.SevenC] -- 7C exists now

---@class kext
local __ = {
	Arch = "Any", -- sometimes x86_64, etc. abnormal.
	BundlePath = "Example.kext",
	Comment = "V6.9.0 | IAMNOTANOCATUSER", -- normally BundlePath or user specified
	Enabled = true,
	ExecutablePath = "Contents/MacOS/Example", --can be empty
	MaxKernel = "12.34.5",
	MinKernel = "5.43.21",
	PlistPath = "Contents/Info.plist", -- Almost always this
}

---@type kext
local __ = nil

---@class kexts
local kexts = {
	normal = {Example = __},
	plugin = {Example = __},
	disabled = {
		normal = {Example = __},
		plugin = {Example = __},
	},
	has = {Example = true} -- Everything in name = true format
}
kexts.has.Example = nil

---@class driver
local __ = {
	Arguments = "",
	Comment = "Example.efi",
	Enabled = true,
	LoadEarly = true,
	Path = "Example.efi",
}

---@type driver
local __ = nil

---@class drivers
local drivers = {
	enabled = {Example = __},
	disabled = {Example = __},
	has = {Example = true} -- Everything in name = true format
}
drivers.has.Example = nil

---@class ssdt
local __ = {
	Comment = "SSDT-EXAMPLE.aml",
	Enabled = true,
	Path = "SSDT-EXAMPLE.aml"
}

---@type ssdt
local __ = nil

---@class ssdts
local ssdts = {
	enabled = {Example = __},
	disabled = {Example = __},
	has = {Example = true} -- Everything in name = true format
}
ssdts.has.Example = nil

---@class tool
local __ = {
	Comment = "Example.efi",
	RealPath = false,
	Flavour = "Auto",
	Name = "Example.efi",
	TextMode = false,
	Enabled = true,
	Arguments = "",
	Path = "Example.efi",
	Auxiliary = true
}

---@type tool
local __ = nil

---@class tools
local tools = {
	enabled = {Example = __},
	disabled = {Example = __},
	has = {Example = true} -- Everything in name = true format
}
tools.has.Example = nil

local __ = nil

local smt = setmetatable
local mt = {
	__call = function (t, k)
		return t[k]
	end
}
smt(kexts.has, mt)
smt(ssdts.has, mt)
smt(drivers.has, mt)
smt(tools.has, mt)

local ensure = {
	ACPI = {Add = {}},
	UEFI = {Drivers = {}},
	Kernel = {Add = {}},
	Misc = {Tools = {}},
}

local function ef(t, o, p)
	local p = p or ""
	for k, v in pairs(t) do
		if not rawget(o, k) then
			if type(v) == "table" and next(v) then
				ef(v, o, p..k..".")
			else
				o[k] = v
				mashprinted[p..k] = true
				table.insert(missing, p..k)
			end
		end
	end
end

ef(ensure, plist)

for _, v in pairs(plist.ACPI.Add) do
	local name = v.Path:match("(.+).aml")
	ssdts[v.Enabled and "enabled" or "disabled"][name] = v
	ssdts.has[name] = v.Enabled
end

if type(plist.UEFI.Drivers[1]) == "string" then
	for _, v in pairs(plist.UEFI.Drivers) do
		local name = v:match("(.+).efi")
		drivers[v.Enabled and "enabled" or "disabled"][name] = v
		drivers.has[name] = true -- Since this is an array
	end
else
	for _, v in pairs(plist.UEFI.Drivers) do
		local name = v.Path:match("(.+).efi")
		drivers[v.Enabled and "enabled" or "disabled"][name] = v
		drivers.has[name] = v.Enabled
	end
end
---@param v kext
for _, v in pairs(plist.Kernel.Add) do
	local kextname = v.BundlePath:match "/?([^/]+).kext$"
	local kxts = v.Enabled and kexts or kexts.disabled
	kxts[v.BundlePath:match("/") and "plugin" or "normal"][kextname] = v
	kexts.has[kextname] = v.Enabled
end

for _, v in pairs(plist.Misc.Tools) do
	local name = v.Path:match("(.+).efi")
	tools[v.Enabled and "enabled" or "disabled"][name] = v
	tools.has[name] = v.Enabled
end

local suc, config = pcall(function() require "occrconfig" end)
if not suc then
	print("Warning: Cannot import config")
	config = {}
end

---@class args
local args = {
	plist = plist,
	rawplist = rawplist,
	kexts = kexts,
	tools = tools,
	drivers = drivers,
	ssdts = ssdts,

	config = config,
	sblist = sblist,
	util = util,
}

---@diagnostic disable-next-line: param-type-mismatch
local dects, order = defaultdectsloader(args)
args.detections = dects
args.order = order
for _, v in pairs(pllist) do
	v(args)
end

---@class occrreturns
local returns = {
	result = {
		Example = {
			total = 5,
			checked = 3,
			result = {
				"Hello world!"
			}
		}
	},
	missing = missing,
	order = order,
	errormsges = {"error here", "stack trace"},
}
returns.errormsges = {}
returns.result.Example = nil

---@diagnostic disable-next-line: param-type-mismatch
for _, k in pairs(order) do
	local v = args.detections[k]
	if type(v) == "table" and next(v) then -- Skip when empty
		local t = {}
		local total, checked = 0, 0
		for _, v in pairs(v) do
			local suc, msg, check = pcall(v)
			if suc then
				if msg then
					table.insert(t, msg)
					if check ~= false then
						checked = checked + 1
					end
				end
				if check ~= false and msg ~= false then
					total = total + 1
				end
			else
				util.spit(msg)
			end
		end
		returns.result[k] = {checked = checked, total = total, result = t}
	end
end

returns.errormsges = util.geterrormsges()

return returns, args
end
return occr