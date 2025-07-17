-- plist returns the plist in Lua Tables, raw is just the plist as string
-- kexts is Kernel.Add(with key being the kext name), and same goes for tools, drivers, ssdts
-- kextsshow is only reserved for detections.lua, it is rarely used
-- kextsarrar, driversarray is kexts and drivers, in array format to not make table.concat mad
-- The tool assumes `proppy.lua` or `plugin.lua` is the plugin name by default

-- note: NVRAM.Add["7C"] is equal to longer version of that

local injection = function(detections, order, plist, raw, kexts, tools, drivers, ssdts, kextsshow, kextsarray, driversarray)
	detections["Test!"] = {} -- Creates new category
	table.insert(order, "Test!") -- append test to the last line
	table.insert(detections["Test!"], function() -- Basic check to see if RebaseRegions is enabled
		if plist.ACPI.Quirks.RebaseRegions then
			return "RebaseRegions is enabled"
		end
	end)
	table.insert(detections["Test!"], function() -- Bad practice, but works as an example.
		if not plist.ACPI.Quirks.RebaseRegions then   -- If false is being returned, it will not count towards the total
			return "RebaseRegions is disabled", false
		end
		return false
	end)
end

return injection