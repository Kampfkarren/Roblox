local weakInstanceTable = {
	__tostring = function()
		return "<Weak Instance Table>"
	end,

	__newindex = function(self, key, value)
		assert(typeof(key) == "Instance", "keys need to be an Instance")
		assert(key:IsDescendantOf(game), "key is not a descendant of the DataModel")
		rawset(self, key, value)

		key.AncestryChanged:Connect(function()
			if not key:IsDescendantOf(game) then
				rawset(self, key, nil)
			end
		end)
	end,
}

return function()
	return setmetatable({}, weakInstanceTable)
end
