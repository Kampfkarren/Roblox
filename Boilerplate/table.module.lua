local newTable = {}

newTable.contains = function(tbl, val)
	for i,v in pairs(tbl) do
		if v == val then
			return i
		end
	end

	return false
end

newTable.len = function(tbl)
	local len = 0

	for _,_ in pairs(tbl) do
		len = len + 1
	end

	return len
end

newTable.keys = function(tbl)
	local ret = {}

	for key,_ in pairs(tbl) do
		table.insert(ret, key)
	end

	return ret
end

newTable.values = function(tbl)
	local ret = {}

	for _,val in pairs(tbl) do
		table.insert(ret, val)
	end

	return ret
end

--sort by keys
newTable.xsort = function(tbl, sort)
	local keys = newTable.keys(tbl)

	table.sort(keys, sort)

	return function()
		if #keys == 0 then
			return nil
		end

		local nextValue = table.remove(keys, 1)

		return nextValue, tbl[nextValue]
	end
end

--sort by values
newTable.vsort = function(tbl, sort)
	sort = sort or function(x, y)
		return x > y
	end

	return newTable.xsort(tbl, function(x, y)
		return sort(tbl[x], tbl[y])
	end)
end

newTable.choice = function(tbl, resultCount)
	resultCount = resultCount or 1

	local results = {}

	--clone the table
	local clone = {}

	for i,v in pairs(tbl) do
		clone[i] = v
	end

	local keys = newTable.keys(clone)

	for _=1,math.min(#tbl, math.max(resultCount, 1)) do
		table.insert(results, tbl[table.remove(keys, math.random(#keys))])
	end

	return unpack(results)
end

newTable.one = function(tbl)
	return tbl[math.random(#tbl)]
end

newTable.shallow = function(tbl)
	local clone = {}

	for key,val in pairs(tbl) do
		clone[key] = val
	end

	return clone
end

newTable.deep = function(tbl)
	local clone = {}

	for key,val in pairs(tbl) do
		if typeof(val) == "table" then
			clone[key] = newTable.deep(val)
		else
			clone[key] = val
		end
	end

	return clone
end

newTable.cloneKeys = function(tbl)
	local ret = {}

	for key,_ in pairs(tbl) do
		ret[key] = true
	end

	return ret
end

newTable.dump = function(tbl, prefix)
	prefix = prefix or ""

	for key,val in pairs(tbl) do
		print(("%s%s = %s"):format(prefix, tostring(key), tostring(val)))

		if typeof(val) == "table" then
			newTable.dump(val, ("%s.%s"):format(prefix, key))
		end
	end
end

newTable.merge = function(tbl, ...)
	local ret = {}

	for _,tbl in pairs({tbl, ...}) do
		for _,value in pairs(tbl) do
			table.insert(ret, value)
		end
	end

	return ret
end

return setmetatable(newTable, {
	__index = table
})
