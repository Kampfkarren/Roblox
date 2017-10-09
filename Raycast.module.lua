return function(ray, blacklist, partToCheck)
	blacklist = blacklist or {}
	local results = {}
	
	while true do
		results = {workspace:FindPartOnRayWithIgnoreList(ray, blacklist)}
		
		local hit = results[1]
		
		if not hit then
			break
		else
			local canCollideWith = partToCheck and partToCheck:CanCollideWith(hit) or hit.CanCollide
			
			if canCollideWith then
				break
			else
				table.insert(blacklist, hit)
			end
		end
	end
	
	return unpack(results)
end
