local function coroutineFunction(parent, childName, placeholder)
	local childAdded

	childAdded = parent.ChildAdded:connect(function(child)
		if child.Name == childName then
			childAdded:disconnect()

			for _,queued in pairs(placeholder:GetChildren()) do
				queued.Parent = child
			end

			placeholder:Destroy()
		end
	end)
end

return function(parent, childName)
	local child = parent:FindFirstChild(childName)

	if not child then
		child = Instance.new("Model")
		coroutine.wrap(coroutineFunction)(parent, childName, child)
	end

	return child
end
