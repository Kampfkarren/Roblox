local lfs = require("lfs")

local LOAD_MODULES = {
	{"testez/lib", "TestEZ"},
	{"tests", "Tests"},
}

package.path = package.path .. ";?/init.lua"

-- Monkey patches
_G.Random = {
	new = function()
		return {
			NextNumber = function() return 0 end,
		}
	end
}

local lemur = require("lemur")
local habitat = lemur.Habitat.new()

local typeof = habitat.environment.typeof
habitat.environment.typeof = function(instance)
	local meta = getmetatable(instance)
	return (meta and meta["TYPEOF_HACK"]) or typeof(instance)
end

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

habitat:loadFromFs("../DataStore2").Parent = Modules

for name in lfs.dir("..") do
	local realName = name:match("(.+)%.module%.lua$")
	if realName then
		local file = habitat:loadFromFs("../" .. name)
		file.Name = realName
		file.Parent = Modules
	end
end

local MockDataStoreService = habitat:loadFromFs("MockDataStoreService/lib")
MockDataStoreService.Name = "DataStoreService"

local MockDataStoreConstants = habitat:require(MockDataStoreService.MockDataStoreService.MockDataStoreConstants)
MockDataStoreConstants.BUDGETING_ENABLED = false
MockDataStoreConstants.LOGGING_ENABLED = false
MockDataStoreConstants.WRITE_COOLDOWN = 0
MockDataStoreConstants.YIELD_TIME_MAX = 0

local gamePrototype = getmetatable(habitat.game).class.prototype
local oldGetService = gamePrototype.GetService

local setErrorRate = lemur.Instance.new("BindableEvent", habitat.game)
setErrorRate.Name = "SET_ERROR_RATE"

setErrorRate.Event:Connect(function(rate)
	MockDataStoreConstants.SIMULATE_ERROR_RATE = rate
end)

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
