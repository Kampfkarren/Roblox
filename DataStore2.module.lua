--[[
	DataStore2: A wrapper for data stores that caches and saves player's data.
	
	DataStore2(dataStoreName, player) - Returns a DataStore2 DataStore
	
	DataStore2 DataStore:
	- Get([defaultValue])
	- GetTableKey(key)
	- Set(value)
	- SetTableKey(key, value)
	- Update(updateFunc)
	- Increment(value)
	- Save()
	- OnUpdate(callback)
	- BindToClose(callback)
	
	local coinStore = DataStore2("Coins", player)
	
	To give a player coins:
	
	coinStore:Increment(50)
	
	To get the current player's coins:
	
	coinStore:Get()
--]]

--Required components
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local table = require(game:GetService("ReplicatedStorage").Boilerplate.table)

--DataStore object
local DataStore = {}

--Internal functions
function DataStore:_GetRaw()
	self.value = self.dataStore:GetAsync(self.key)
	self.haveValue = true
end

function DataStore:_Update()
	for _,callback in pairs(self.callbacks) do
		callback(self.value)
	end
end

--Public functions
function DataStore:Get(defaultValue, dontAttemptGet)
	if not self.hasValue and dontAttemptGet then
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

local HttpService = game:GetService("HttpService")

--[[
function DataStore:GetTable(defaultValue)
	self.isJson = true
	
	local value = self:Get(defaultValue)
	
	if typeof(value) == "string" then
		return HttpService:JSONDecode(value)
	else
		return value
	end
end
]]

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

function DataStore:Increment(value)
	if not self.value then
		warn("no value to increment")
	end
	
	self.value = self.value + value
	self:_Update()
end

function DataStore:OnUpdate(callback)
	table.insert(self.callbacks, callback)
end

function DataStore:Save()
	if self.value ~= nil then
		local value = self.value
		
		pcall(self.dataStore.SetAsync, self.dataStore, self.key, value)
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
	
	dataStore.dataStore = DataStoreService:GetDataStore(dataStoreName)
	dataStore.name = dataStoreName
	dataStore.key = player.UserId
	dataStore.callbacks = {}
	dataStore.bindToClose = {}
	
	setmetatable(dataStore, DataStoreMetatable)
	
	local event = Instance.new("BindableEvent")
	
	game:BindToClose(function()
		event.Event:wait()
		
		local value = dataStore:Get(nil, true)
		
		for _,bindToClose in pairs(dataStore.bindToClose) do
			bindToClose(player, value)
		end
	end)
	
	Players.PlayerRemoving:connect(function(player)
		dataStore:Save()
		event:Fire()
	end)
	
	if not DataStoreCache[player] then
		DataStoreCache[player] = {}
	end
	
	DataStoreCache[player][dataStoreName] = dataStore
	
	spawn(function()
		while wait(30) do
			dataStore:Save()
		end
	end)
	
	return dataStore
end

return DataStore2
