local weakInstanceTable = {}
weakInstanceTable.__tostring = "<Weak Instance Table>"

function weakInstanceTable:__newindex(key, value)
	assert(typeof(key) == "Instance", "keys need to be an Instance")
	assert(key:IsDescendantOf(game), "key is not a descendant of the DataModel")
	rawset(self, key, value)

	key.AncestryChanged:connect(function()
		if not key:IsDescendantOf(game) then
			rawset(self, key, nil)
		end
	end)
end

return function()
	return setmetatable({}, weakInstanceTable)
end
