local TableUtil = {}

function TableUtil.clone(tbl)
	local clone = {}

	for key, value in pairs(tbl) do
		if typeof(value) == "table" then
			clone[key] = TableUtil.clone(value)
		else
			clone[key] = value
		end
	end

	return clone
end

function TableUtil.sync(tbl, default)
	local changed = false

	for defaultKey, defaultValue in pairs(default) do
		if tbl[defaultKey] == nil then
			if typeof(defaultValue) == "table" then
				tbl[defaultKey] = TableUtil.copy(defaultValue)
			else
				tbl[defaultKey] = defaultValue
			end

			changed = true
		elseif typeof(tbl[defaultKey]) == "table" then
			TableUtil.sync(tbl[defaultKey], defaultValue)
		end
	end

	return changed
end

return TableUtil
