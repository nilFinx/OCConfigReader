
local injection = function(args)
    local detections = args.detections
    local plist = args.plist
	detections["ACPI > Patch"] = {}
    local dects = detections["ACPI > Patch"]
	table.insert(args.order, 2, "ACPI > Patch") -- After "Info"
    for _, v in pairs(plist.ACPI.Patch) do
        if not v.Enabled then
            table.insert(dects, function() end) -- Add count, do nothing
        else
            table.insert(dects, function()
                return v.Comment
            end)
        end
    end
end

return injection