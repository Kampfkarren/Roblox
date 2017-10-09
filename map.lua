return function(func, list)
	for index,value in pairs(list) do
		list[index] = func(value)
	end
	
	return list
end
