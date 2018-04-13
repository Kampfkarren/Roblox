--[[
	DataStore2: A wrapper for data stores that caches and saves player's data.
	
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

--Required components
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local table = require(game:GetService("ReplicatedStorage").Boilerplate.table)
local RegularSave = false
local RegularSaveNum = 300
local SaveInStudio = game.ServerStorage.OverrideStudioClose.Value

--DataStore object
local DataStore = {}

--Internal functions
function DataStore:_GetRaw()
	self.value = self.dataStore:GetAsync(self.key)
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
	
	if self.value ~= nil then
		pcall(self.dataStore.UpdateAsync, self.dataStore, self.key, function()
			return self.value
		end)
		
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
	
	dataStore.dataStore = DataStoreService:GetDataStore(dataStoreName)
	dataStore.name = dataStoreName
	dataStore.player = player
	dataStore.key = player.UserId
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
