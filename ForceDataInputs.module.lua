return function(data, ply_to_kick, force)
	for i,v in pairs(data) do
		if typeof(v) ~= force[i] then
			warn("invalid data inputs")
			ply_to_kick:Kick(0x02)
			return false
		end
	end
	
	return true
end
