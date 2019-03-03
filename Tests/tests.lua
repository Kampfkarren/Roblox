local lfs = require("lfs")

local LOAD_MODULES = {
	{"testez/lib", "TestEZ"},
	{"tests", "Tests"},
}

package.path = package.path .. ";?/init.lua"

-- Monkey patches
_G.Random = {
	new = function()
		return {}
	end
}

local lemur = require("lemur")
local habitat = lemur.Habitat.new()

local Root = lemur.Instance.new("Folder")
Root.Name = "Root"

for _, module in pairs(LOAD_MODULES) do
	local container = habitat:loadFromFs(module[1])
	container.Name = module[2]
	container.Parent = Root
end

local Modules = lemur.Instance.new("Folder")
Modules.Name = "Modules"
Modules.Parent = Root

for name in lfs.dir("..") do
	local realName = name:match("(.+)%.module%.lua$")
	if realName then
		local file = habitat:loadFromFs("../" .. name)
		file.Name = realName
		file.Parent = Modules
	end
end

-- Edge cases because I messed up the repo lol
local tableModule = habitat:loadFromFs("../Boilerplate/table.module.lua")
tableModule.Name = "table"
tableModule.Parent = Modules.DataStore2

local MockDataStoreService = habitat:loadFromFs("MockDataStoreService/lib")
MockDataStoreService.Name = "DataStoreService"

local MockDataStoreConstants = habitat:require(MockDataStoreService.MockDataStoreService.MockDataStoreConstants)
MockDataStoreConstants.BUDGETING_ENABLED = false
-- MockDataStoreConstants.LOGGING_ENABLED = true
MockDataStoreConstants.WRITE_COOLDOWN = 0
MockDataStoreConstants.YIELD_TIME_MAX = 0

local gamePrototype = getmetatable(habitat.game).class.prototype
local oldGetService = gamePrototype.GetService

local bindToClose = lemur.Instance.new("BindableEvent", habitat.game)
bindToClose.Name = "BIND_TO_CLOSE"

function gamePrototype:BindToClose(callback)
	bindToClose.Event:Connect(callback)
end

function gamePrototype:GetService(serviceName)
	if serviceName == "DataStoreService" then
		local mockDataStore = habitat:require(MockDataStoreService)
		return mockDataStore
	end

	local service = self:FindFirstChildOfClass(serviceName)
	assert(service, ("Can't find service %s"):format(serviceName))
	return service
end

local playerRemoving = lemur.Instance.new("BindableEvent", habitat.game)
playerRemoving.Name = "PLAYER_REMOVING"

local playersPrototype = getmetatable(habitat.game:GetService("Players")).class.prototype
playersPrototype.PlayerRemoving = {
	connect = function(_, callback)
		playerRemoving.Event:Connect(callback)
	end
}

local runServicePrototype = getmetatable(habitat.game:GetService("RunService")).class.prototype
function runServicePrototype:IsServer()
	return true
end

-- Redirect DataStoreRequestType:GetEnumItems()
getmetatable(habitat.environment.Enum.DataStoreRequestType).__index = function(_, index)
	if index == "GetEnumItems" then
		return function() return {} end
	else
		return 0
	end
end

habitat.environment.UUID = require("uuid.src.uuid")
habitat.environment.utf8 = {
	len = string.len,
}

local runner = require("luacov.runner")
runner.init(".luacov")
runner.pause()

runner.resume()

local TestEZ = habitat:require(Root.TestEZ)

local results = TestEZ.TestBootstrap:run(
	{Root.Tests, util},
	TestEZ.Reporters.TextReports
)

-- luacov: disable
if results.failureCount > 0 then
	os.exit(1)
end
-- luacov: enable
