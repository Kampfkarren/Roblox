return function(model)
	local mass = 0

	for _, object in pairs(model:GetDescendants()) do
		if object:IsA("BasePart") then
			mass = mass + object:GetMass()
		end
	end

	return mass
end
