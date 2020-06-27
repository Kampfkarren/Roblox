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

	for key, value in pairs(default) do
		if not tbl[key] then
			if typeof(value) == "table" then
				tbl[key] = TableUtil.copy(value)
			else
				tbl[key] = value
			end

			changed = true
		elseif typeof(tbl[key]) == "table" then
			TableUtil.sync(tbl[key], value)
		end
	end

	return changed
end

return TableUtil
