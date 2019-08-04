local Verifier = {}

function Verifier.typeValid(data)
	return type(data) ~= "userdata", typeof(data)
end

function Verifier.scanValidity(tbl, passed, path)
	if type(tbl) ~= "table" then
		return Verifier.scanValidity({input = tbl}, {}, {})
	end
	passed, path = passed or {}, path or {"input"}
	passed[tbl] = true
	local tblType
	do
		local key, value = next(tbl)
		if type(key) == "number" then
			tblType = "Array"
		else
			tblType = "Dictionary"
		end
	end
	local last = 0
	for key, value in next, tbl do
		path[#path + 1] = tostring(key)
		if type(key) == "number" then
			if tblType == "Dictionary" then
				return false, path, "Mixed Array/Dictionary"
			elseif key%1 ~= 0 then  -- if not an integer
				return false, path, "Non-integer index"
			elseif key == math.huge or key == -math.huge then
				return false, path, "(-)Infinity index"
			end
		elseif type(key) ~= "string" then
			return false, path, "Non-string key", typeof(key)
		elseif tblType == "Array" then
			return false, path, "Mixed Array/Dictionary"
		end
		if tblType == "Array" then
			if last ~= key - 1 then
				return false, path, "Array with non-sequential indexes"
			end
			last = key
		end
		local isTypeValid, valueType = Verifier.typeValid(value)
		if not isTypeValid then
			return false, path, "Invalid type", valueType
		end
		if type(value) == "table" then
			if passed[value] then
				return false, path, "Cyclic"
			end
			local isValid, keyPath, reason, extra = Verifier.scanValidity(value, passed, path)
			if not isValid then
				return isValid, keyPath, reason, extra
			end
		end
		path[#path] = nil
	end
	passed[tbl] = nil
	return true
end

function Verifier.getStringPath(path)
	return table.concat(path, ".")
end

function Verifier.warnIfInvalid(input)
	local isValid, keyPath, reason, extra = Verifier.scanValidity(input)
	if not isValid then
		if extra then
			warn("Invalid at "..Verifier.getStringPath(keyPath).." because: "..reason.." ("..tostring(extra)..")")
		else
			warn("Invalid at "..Verifier.getStringPath(keyPath).." because: "..reason)
		end
	end

	return isValid
end

return Verifier
