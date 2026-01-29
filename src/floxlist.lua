local xmlparser = require "xmlparser"
local b64 = require "base64"

local types

-- Some types aren't supported, but that's okay. At least it works for OpenCore.
-- The unsupported type in question is date and real. Also UID? I think that was a real thing?

local function parse(plist)

	assert(plist:match("<plist version=\"[.0-9]+\">.+</plist>"), "Failed to parse: Not a plist")
	local suc, plist = xpcall(function(plist)
	---@diagnostic disable-next-line: return-type-mismatch
		local suc, plist = pcall(function(plist) return xmlparser.parse(plist) end, plist)
		if not suc then
			error("Failed to parse: xmlparser issue")
		end

		plist = plist.children[1].children[1].children or error "Failed to parse: Not a plist, or XML parsing issue?"

		local function parseDict(data, array)
			local dict = {}
			for i = 1, #data, array and 1 or 2 do
				local key, vtype, value
				if array then
					vtype = data[i].tag
					value = data[i].children
				else
					key = data[i].children[1].text
					vtype = data[i+1].tag
					value = data[i+1].children
				end

				if vtype == "true" or vtype == "false" then
					value = vtype == "true" and true or false
					vtype = "boolean"
				elseif vtype == "array" then
					if next(value) then
						value = parseDict(value, true)
					else
						value = {}
					end
				elseif vtype == "dict" then
					if next(value) then
						value = parseDict(value)
					else
						value = {}
					end
				elseif types[vtype] then
					value = value[1] and types[vtype](value) or nil
				else
					value = "Unknown type: "..tostring(vtype)
				end
				if array then
					table.insert(dict, value)
				else
					dict[key] = value
				end
			end

			return dict
		end

		types = {
			string = function(data)
				return data[1].text or ""
			end,
			data = function(data)
				return b64.decode(data[1].text)
			end,
			integer = function(data)
				return tonumber(data[1].text)
			end
		}
		
		local pl = parseDict(plist)
		return pl
	end, function(err)
		print(err)
	end, plist)
	if not suc then
		error "Failed to parse plist"
	end
	return plist
end

return parse