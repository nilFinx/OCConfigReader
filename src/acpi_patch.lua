
local injection = function(detections, order, plist)
	detections["ACPI > Patch"] = {}
	table.insert(order, 2, "ACPI > Patch") -- After "Info"
    for _, v in pairs(plist.ACPI.Patch) do
        if not v.Enabled then
            table.insert(detections["ACPI > Patch"], function() end) -- Add count, do nothing
        else
            table.insert(detections["ACPI > Patch"], function()
                return v.Comment
            end)
        end
    end
end

return injection