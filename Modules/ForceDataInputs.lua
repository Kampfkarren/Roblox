return function(data, player, force)
	for index, expected in pairs(force) do
		if expected ~= typeof(data[index]) then
			warn("invalid data inputs")
			player:Kick("invalid data")
			return false
		end
	end

	return true
end
