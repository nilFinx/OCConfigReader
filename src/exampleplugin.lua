-- The tool assumes `proppy.lua` or `plugin.lua` is the plugin name by default

-- note: NVRAM.Add[args.util.SevenC] is equal to longer version of that

local injection = function(args)
	local detections = args.detections
	local plist = args.plist
	local kexts = args.kexts
	local tools = args.tools
	local drivers = args.drivers
	local ssdts = args.ssdts
	detections["Test!"] = {} -- Creates new category
	table.insert(args.order, "Test!") -- append test to the last line
	table.insert(detections["Test!"], function() -- Basic check to see if RebaseRegions is enabled
		if plist.ACPI.Quirks.RebaseRegions then
			return "RebaseRegions is enabled"
		end
	end)
	table.insert(detections["Test!"], function() -- Bad practice, but works as an example.
		if not plist.ACPI.Quirks.RebaseRegions then   -- If false is being returned as the 2nd, it will not count towards the total
			return "RebaseRegions is disabled", false
		end
		return false
	end)
end

return injection