local utils = {}

local errormsges = ""

function utils.geterrormsges()
	local r = errormsges
	errormsges = ""
	return r
end

-- Spit a warning without causing issues
function utils.spit(msg)
	errormsges = errormsges..msg.."\n"
end

-- Assert spit
function utils.aspit(condition, msg)
	if not condition then
		errormsges = errormsges..msg.."\n"
	end
	return condition
end

-- Spit that thang and return an empty table
function utils.nulltable(msg)
	errormsges = errormsges..msg.."\n"
	return {}
end

function utils.osxname(v)
	local ver = type(v) ~= "number" and tonumber(v:match("^%d+.?%d*")) or v
	if ver >= 10.2 and ver <= 10.7 then
		return "Mac OS X "..tostring(v)
	elseif ver == 10.10 then -- 10.8 ~ 10.11
		return "OS X 10.10"
	elseif ver == 10.11 or (ver >= 10.8 and ver <= 10.10) then
		return "OS X "..tostring(v) -- 10.8 ~ 10.11
	else
		return "macOS "..tostring(v)
	end
end

return utils