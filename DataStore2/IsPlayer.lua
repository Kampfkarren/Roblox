-- This function is monkey patched to return MockDataStoreService during tests
local IsPlayer = {}

function IsPlayer.Check(object)
	return typeof(object) == "Instance" and object.ClassName == "Player"
end

return IsPlayer
