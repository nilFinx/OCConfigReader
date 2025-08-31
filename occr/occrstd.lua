function asrt(condition, msg)
    if not condition then
        print(msg)
        os.exit(1)
    end
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