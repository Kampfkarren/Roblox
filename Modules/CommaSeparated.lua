return function(list)
	if #list == 1 then
		return tostring(list[1])
	elseif #list == 2 then
		return list[1] .. " and " .. list[2]
	else
		local lastItem = table.remove(list)
		local text = table.concat(list, ", ") .. ", and " .. lastItem
		table.insert(list, lastItem)
		return text
	end
end
