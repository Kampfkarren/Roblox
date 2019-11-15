-- This function is monkey patched to return MockDataStoreService during tests
local DataStoreService = game:GetService("DataStoreService")

local DataStoreServiceRetriever = {}

function DataStoreServiceRetriever.Get()
	return DataStoreService
end

return DataStoreServiceRetriever
