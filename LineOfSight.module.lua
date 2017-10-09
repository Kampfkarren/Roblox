local Raycast = require(game:GetService("ReplicatedStorage").Raycast)

--Checks if given a range, if origin has line of sight with character.
return function(origin, character, range, blacklist)
	if typeof(origin) == "Instance" then
		origin = origin.Position
	end
	
	local hit, point = Raycast(Ray.new(origin, (origin - character.HumanoidRootPart.Position).Unit * -range), blacklist)
	
	return hit and hit:IsDescendantOf(character), point
end
