-- Standard saving of data stores
-- The key you provide to DataStore2 is the name of the store with GetDataStore
-- GetAsync/UpdateAsync are then called based on the user ID
local DataStoreServiceRetriever = require(script.Parent.Parent.DataStoreServiceRetriever)
local Promise = require(script.Parent.Parent.Promise)

local Standard = {}
Standard.__index = Standard

function Standard:Get()
	return Promise.async(function(resolve)
		self.storeData = self.dataStore:GetAsync(self.userId)

		resolve(self.storeData)
	end)
end

function Standard:Set(value)
	return Promise.async(function(resolve)
		local datastoreKeyResponse

		if self.storeData == nil then
			datastoreKeyResponse = self.dataStore:SetAsync(self.userId, value, { self.userId })
		else
			datastoreKeyResponse = self.dataStore:UpdateAsync(self.userId, function()
				return value
			end)
		end

		resolve(datastoreKeyResponse)
	end)
end

function Standard.new(dataStore2)
	return setmetatable({
		dataStore = DataStoreServiceRetriever.Get():GetDataStore(dataStore2.Name),
		userId = dataStore2.UserId,
	}, Standard)
end

return Standard
