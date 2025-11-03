function assert(condition, msg)
    if not condition then
        print(msg)
        os.exit(1)
    end
end

function error(message)
	print(message)
	os.exit(1)
end

-- Spit a warning without causing issues
function spit(msg)
	errormsges = errormsges..msg.."\n"
end

-- Assert spit
function aspit(condition, msg)
	if not condition then
		errormsges = errormsges..msg.."\n"
	end
	return condition
end

-- Spit that thang and return an empty table
function nulltable(msg)
	errormsges = errormsges..msg.."\n"
	return {}
end

function osxname(v)
	if v >= 10.12 then
		return "macOS "..tostring(v)
	elseif v >= 10.8 then
		return "OS X "..tostring(v)
	elseif v == 10.10 then
		return "OS X 10.10"
	else
		return "Mac OS X "..tostring(v)
	end
end
