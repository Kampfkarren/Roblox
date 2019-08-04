--[[
	berezaa's method of saving data (from the dev forum):

	What I do and this might seem a little over-the-top but it's fine as long as you're not using datastores excessively elsewhere is have a datastore and an ordereddatastore for each player. When you perform a save, add a key (can be anything) with the value of os.time() to the ordereddatastore and save a key with the os.time() and the value of the player's data to the regular datastore. Then, when loading data, get the highest number from the ordered data store (most recent save) and load the data with that as a key.

	Ever since I implemented this, pretty much no one has ever lost data. There's no caches to worry about either because you're never overriding any keys. Plus, it has the added benefit of allowing you to restore lost data, since every save doubles as a backup which can be easily found with the ordereddatastore

	edit: while there's no official comment on this, many developers including myself have noticed really bad cache times and issues with using the same datastore keys to save data across multiple places in the same game. With this method, data is almost always instantly accessible immediately after a player teleports, making it useful for multi-place games.
--]]

local DataStoreService = game:GetService("DataStoreService")

local OrderedBackups = {}
OrderedBackups.__index = OrderedBackups

function OrderedBackups:Get()
	local success, value = pcall(function()
		return self.orderedDataStore:GetSortedAsync(false, 1):GetCurrentPage()[1]
	end)

	if not success then
		return false, value
	end

	if value then
		local mostRecentKeyPage = value

		local recentKey = mostRecentKeyPage.value
		self.dataStore2:Debug("most recent key", mostRecentKeyPage)
		self.mostRecentKey = recentKey

		local success, value = pcall(function()
			return self.dataStore:GetAsync(recentKey)
		end)

		if not success then
			return false, value
		end

		return true, value
	else
		self.dataStore2:Debug("no recent key")
		return true, nil
	end
end

function OrderedBackups:Set(value)
	local key = (self.mostRecentKey or 0) + 1

	local success, problem = pcall(function()
		self.dataStore:SetAsync(key, value)
	end)

	if not success then
		return false, problem
	end

	local success, problem = pcall(function()
		self.orderedDataStore:SetAsync(key, key)
	end)

	if not success then
		return false, problem
	end

	self.mostRecentKey = key
	return true
end

function OrderedBackups.new(dataStore2)
	local dataStoreKey = dataStore2.Name .. "/" .. dataStore2.UserId

	local info = {
		dataStore2 = dataStore2,
		dataStore = DataStoreService:GetDataStore(dataStoreKey),
		orderedDataStore = DataStoreService:GetOrderedDataStore(dataStoreKey),
	}

	return setmetatable(info, OrderedBackups)
end

return OrderedBackups
