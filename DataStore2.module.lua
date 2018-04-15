--[[
	DataStore2: A wrapper for data stores that caches, saves player's data, and uses berezaa's method of saving data.
	
	DataStore2(dataStoreName, player) - Returns a DataStore2 DataStore
	
	DataStore2 DataStore:
	- Get([defaultValue])
	- Set(value)
	- Update(updateFunc)
	- Increment(value, defaultValue)
	- Save()
	- OnUpdate(callback)
	- BindToClose(callback)
	
	local coinStore = DataStore2("Coins", player)
	
	To give a player coins:
	
	coinStore:Increment(50)
	
	To get the current player's coins:
	
	coinStore:Get()
--]]

--[[
	berezaa's method of saving data (from the dev forum):
	
	What I do and this might seem a little over-the-top but it's fine as long as you're not using datastores excessively elsewhere is have a datastore and an ordereddatastore for each player. When you perform a save, add a key (can be anything) with the value of os.time() to the ordereddatastore and save a key with the os.time() and the value of the player's data to the regular datastore. Then, when loading data, get the highest number from the ordered data store (most recent save) and load the data with that as a key.
	
	Ever since I implemented this, pretty much no one has ever lost data. There's no caches to worry about either because you're never overriding any keys. Plus, it has the added benefit of allowing you to restore lost data, since every save doubles as a backup which can be easily found with the ordereddatastore
	
	edit: while there's no official comment on this, many developers including myself have noticed really bad cache times and issues with using the same datastore keys to save data across multiple places in the same game. With this method, data is almost always instantly accessible immediately after a player teleports, making it useful for multi-place games.
--]]

--Required components
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local table = require(game:GetService("ReplicatedStorage").Boilerplate.table)
local RegularSave = false
local RegularSaveNum = 300
local SaveInStudio = false
local Debug = false

--DataStore object
local DataStore = {}

--Internal functions
function DataStore:Debug(...)
	if Debug then
		print(...)
	end
end

function DataStore:_GetRaw()
	local mostRecentKeyPage = self.orderedDataStore:GetSortedAsync(false, 1):GetCurrentPage()[1]
	
	if mostRecentKeyPage then
		local recentKey = mostRecentKeyPage.value
		self:Debug("most recent key", mostRecentKeyPage)
		
		self.value = self.dataStore:GetAsync(recentKey)
	else
		self:Debug("no recent key")
		
		self.value = nil
	end
	
	self.haveValue = true
end

function DataStore:_Update()
	for _,callback in pairs(self.callbacks) do
		callback(self.value, self)
	end
	
	self.haveValue = true
end

--Public functions
function DataStore:Get(defaultValue, dontAttemptGet)
	if not self.haveValue and dontAttemptGet then
		return self.value
	end
	
	while not self.haveValue and not pcall(self._GetRaw, self) do end
	
	local value
	
	if self.value == nil and defaultValue ~= nil then --not using "not" because false is a possible value
		value = defaultValue
	else
		value = self.value
	end
	
	if typeof(value) == "table" and self.value ~= nil then
		value = table.deep(value)
	end
	
	self.value = value
	
	return value
end

function DataStore:Set(value)
	if typeof(value) == "table" then
		self.value = table.deep(value)
	else
		self.value = value
	end
	
	self:_Update()
end

function DataStore:Update(updateFunc)
	self.value = updateFunc(self.value)
	self:_Update()
end

function DataStore:Increment(value, defaultValue)
	self:Set(self:Get(defaultValue) + value)
end

function DataStore:OnUpdate(callback)
	table.insert(self.callbacks, callback)
end

function DataStore:Save()
	if game:GetService("RunService"):IsStudio() and not SaveInStudio then
		warn(("Data store %s attempted to save in studio while SaveInStudio is false."):format(self.name))
		return
	end
	
	--TODO: check last saved value if its the same
	
	if self.value ~= nil then
		local key = os.time()
		self.dataStore:SetAsync(key, self.value)
		self.orderedDataStore:SetAsync(key, key)
		
		print("saved "..self.name)
	end
end

function DataStore:BindToClose(callback)
	table.insert(self.bindToClose, callback)
end

function DataStore:GetKeyValue(key)
	return (self.value or {})[key]
end

function DataStore:SetKeyValue(key, newValue)
	if not self.value then
		self.value = self:Get({})
	end
	
	self.value[key] = newValue
end

local DataStoreMetatable = {}

DataStoreMetatable.__index = DataStore

--Library
local DataStoreCache = {}

local function DataStore2(dataStoreName, player)
	if DataStoreCache[player] and DataStoreCache[player][dataStoreName] then
		return DataStoreCache[player][dataStoreName]
	end
	
	local dataStore = {}
	local dataStoreKey = dataStoreName .. "/" .. player.UserId
	
	dataStore.dataStore = DataStoreService:GetDataStore(dataStoreKey)
	dataStore.orderedDataStore = DataStoreService:GetOrderedDataStore(dataStoreKey)
	dataStore.name = dataStoreName
	dataStore.player = player
	dataStore.callbacks = {}
	dataStore.bindToClose = {}
	
	setmetatable(dataStore, DataStoreMetatable)
	
	local event, fired = Instance.new("BindableEvent"), false
	
	game:BindToClose(function()
		if not fired then
			event.Event:wait()
		end
		
		local value = dataStore:Get(nil, true)
		
		for _,bindToClose in pairs(dataStore.bindToClose) do
			bindToClose(player, value)
		end
	end)
	
	Players.PlayerRemoving:connect(function(player)
		dataStore:Save()
		event:Fire()
		fired = true
	end)
	
	if not DataStoreCache[player] then
		DataStoreCache[player] = {}
	end
	
	DataStoreCache[player][dataStoreName] = dataStore
	
	spawn(function()
		while RegularSave and wait(RegularSaveNum) do
			dataStore:Save()
		end
	end)
	
	return dataStore
end

return DataStore2
