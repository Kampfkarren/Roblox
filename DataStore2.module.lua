--[[
	DataStore2: A wrapper for data stores that caches, saves player's data, and uses berezaa's method of saving data.
	
	DataStore2(dataStoreName, player) - Returns a DataStore2 DataStore
	
	DataStore2 DataStore:
	- Get([defaultValue])
	- Set(value)
	- Update(updateFunc)
	- Increment(value, defaultValue)
	- BeforeInitialGet(modifier)
	- BeforeSave(modifier)
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
local SaveInStudioObject = game:GetService("ServerStorage"):FindFirstChild("SaveOnStudio")
local SaveInStudio = SaveInStudioObject and SaveInStudioObject.Value
local Debug = false

local Verifier = {}

function Verifier.typeValid(data)
	return type(data) ~= 'userdata', typeof(data)
end

function Verifier.scanValidity(tbl, passed, path)
	if type(tbl) ~= 'table' then
		return Verifier.scanValidity({input = tbl}, {}, {})
	end
	passed, path = passed or {}, path or {'input'}
	passed[tbl] = true
	local tblType
	do
		local key, value = next(tbl)
		if type(key) == 'number' then
			tblType = 'Array'
		else
			tblType = 'Dictionary'
		end
	end
	local last = 0
	for key, value in next, tbl do
		path[#path + 1] = tostring(key)
		if type(key) == 'number' then
			if tblType == 'Dictionary' then
				return false, path, 'Mixed Array/Dictionary'
			elseif key%1 ~= 0 then  -- if not an integer
				return false, path, 'Non-integer index'
			elseif key == math.huge or key == -math.huge then
				return false, path, '(-)Infinity index'
			end
		elseif type(key) ~= 'string' then
			return false, path, 'Non-string key', typeof(key)
		elseif tblType == 'Array' then
			return false, path, 'Mixed Array/Dictionary'
		end
		if tblType == 'Array' then
			if last ~= key - 1 then
				return false, path, 'Array with non-sequential indexes'
			end
			last = key
		end
		local isTypeValid, valueType = Verifier.typeValid(value)
		if not isTypeValid then
			return false, path, 'Invalid type', valueType
		end
		if type(value) == 'table' then
			if passed[value] then
				return false, path, 'Cyclic'
			end
			local isValid, keyPath, reason, extra = Verifier.scanValidity(value, passed, path)
			if not isValid then
				return isValid, keyPath, reason, extra
			end
		end
		path[#path] = nil
	end
	passed[tbl] = nil
	return true
end

function Verifier.getStringPath(path)
	return table.concat(path, '.')
end

function Verifier.warnIfInvalid(input)
	local isValid, keyPath, reason, extra = Verifier.scanValidity(input)
	if not isValid then
		if extra then
			warn('Invalid at '..Verifier.getStringPath(keyPath)..' because: '..reason..' ('..tostring(extra)..')')
		else
			warn('Invalid at '..Verifier.getStringPath(keyPath)..' because: '..reason)
		end
	end
	
	return isValid
end

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

--[[**
	<description>
	Gets the result from the data store. Will yield the first time it is called.
	</description>
	
	<parameter name = "defaultValue">
	The default result if there is no result in the data store.
	</parameter>
	
	<parameter name = "dontAttemptGet">
	If there is no cached result, just return nil.
	</parameter>
	
	<returns>
	The value in the data store if there is no cached result. The cached result otherwise.
	</returns>
**--]]
function DataStore:Get(defaultValue, dontAttemptGet)
	if dontAttemptGet then
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
	
	if self.value ~= nil then
		for _,modifier in pairs(self.beforeInitialGet) do
			value = modifier(value, self)
		end
	end
	
	self.value = value
	
	return value
end

--[[**
	<description>
	Sets the cached result to the value provided
	</description>
	
	<parameter name = "value">
	The value
	</parameter>
**--]]
function DataStore:Set(value)
	if typeof(value) == "table" then
		self.value = table.deep(value)
	else
		self.value = value
	end
	
	self:_Update()
end

--[[**
	<description>
	Calls the function provided and sets the cached result.
	</description>
	
	<parameter name = "updateFunc">
	The function
	</parameter>
**--]]
function DataStore:Update(updateFunc)
	self.value = updateFunc(self.value)
	self:_Update()
end

--[[**
	<description>
	Increment the cached result by value.
	</description>
	
	<parameter name = "value">
	The value to increment by.
	</parameter>
	
	<parameter name = "defaultValue">
	If there is no cached result, set it to this before incrementing.
	</parameter>
**--]]
function DataStore:Increment(value, defaultValue)
	self:Set(self:Get(defaultValue) + value)
end

--[[**
	<description>
	Takes a function to be called whenever the cached result updates.
	</description>
	
	<parameter name = "callback">
	The function to call.
	</parameter>
**--]]
function DataStore:OnUpdate(callback)
	table.insert(self.callbacks, callback)
end

--[[**
	<description>
	Takes a function to be called when :Get() is first called and there is a value in the data store. This function must return a value to set to. Used for deserializing.
	</description>
	
	<parameter name = "modifier">
	The modifier function.
	</parameter>
**--]]
function DataStore:BeforeInitialGet(modifier)
	table.insert(self.beforeInitialGet, modifier)
end

--[[**
	<description>
	Takes a function to be called before :Save(). This function must return a value that will be saved in the data store. Used for serializing.
	</description>
	
	<parameter name = "modifier">
	The modifier function.
	</parameter>
**--]]
function DataStore:BeforeSave(modifier)
	table.insert(self.beforeSave, modifier)
end

--[[**
	<description>
	Saves the data to the data store. Called when a player leaves.
	</description>
**--]]
function DataStore:Save()
	if game:GetService("RunService"):IsStudio() and not SaveInStudio then
		warn(("Data store %s attempted to save in studio while SaveInStudio is false."):format(self.name))
		if not SaveInStudioObject then
			warn("You can set the value of this by creating a BoolValue named SaveInStudio in ServerStorage.")
		end
		return
	end
	
	--TODO: check last saved value if its the same
	
	if self.value ~= nil then
		local save = self.value
		
		for _,beforeSave in pairs(self.beforeSave) do
			local success, newSave = pcall(beforeSave, save, self)
			
			if success then
				save = newSave
			else
				warn("Error on BeforeSave: "..newSave)
				return
			end
		end
		
		if not Verifier.warnIfInvalid(save) then return warn("Invalid data while saving") end
		
		local key = os.time()
		self.dataStore:SetAsync(key, save)
		self.orderedDataStore:SetAsync(key, key)
		
		print("saved "..self.name)
	end
end

--[[**
	<description>
	Add a function to be called before the game closes. Fired with the player and value of the data store.
	</description>
	
	<parameter name = "callback">
	The callback function.
	</parameter>
**--]]
function DataStore:BindToClose(callback)
	table.insert(self.bindToClose, callback)
end

--[[**
	<description>
	Gets the value of the cached result indexed by key. Does not attempt to get the current value in the data store.
	</description>
	
	<parameter name = "key">
	The key you're indexing by.
	</parameter>
	
	<returns>
	The value indexed.
	</returns>
**--]]
function DataStore:GetKeyValue(key)
	return (self.value or {})[key]
end

--[[**
	<description>
	Sets the value of the result in the database with the key and the new value. Attempts to get the value from the data store. Does not call functions fired on update.
	</description>
	
	<parameter name = "key">
	The key to set.
	</parameter>
	
	<parameter name = "newValue">
	The value to set.
	</parameter>
**--]]
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
	dataStore.beforeSave = {}
	dataStore.beforeInitialGet = {}
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
	
	Players.PlayerRemoving:connect(function(playerLeaving)
		if playerLeaving == player then
			dataStore:Save()
			event:Fire()
			fired = true
		end
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
