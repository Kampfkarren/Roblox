return function(data, ply_to_kick, force)
	for i,v in pairs(force) do
		if v ~= typeof(data[i]) then
			warn("invalid data inputs")
			ply_to_kick:Kick(0x02)
			return false
		end
	end
	
	return true
end
