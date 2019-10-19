return function(part)
	if part.Parent == nil then return end

	local parent = part

	repeat
		parent = parent.Parent

		if parent:FindFirstChild("Humanoid") then
			return parent
		end
	until parent:IsA("Model")
end
