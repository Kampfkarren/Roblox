local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local LoadRequirementsDictionary = require(ReplicatedStorage.Dictionaries.LoadRequirementsDictionary)

local PlayerStorage = require(ServerScriptService.PlayerStorage)

local requirements = {}
local requirementAdded = Instance.new("BindableEvent")

local LoadRequirement = {}
local requirementsNeeded = 0

for _ in pairs(LoadRequirementsDictionary) do
	requirementsNeeded = requirementsNeeded + 1
end

function LoadRequirement.AddRequirement(requirementName, requirementCallback)
	assert(LoadRequirementsDictionary[requirementName], "Load Requirement not in dictionary: " .. requirementName)

	requirements[requirementName] = {
		name = requirementName,
		callback = requirementCallback
	}

	requirementAdded:Fire()
end

Players.PlayerAdded:connect(function(player)
	local LoadRequirements = PlayerStorage(player).LoadRequirements
	local running = coroutine.running()

	for requirementName in pairs(LoadRequirementsDictionary) do
		local requirement = requirements[requirementName]
		if not requirement then
			warn("Player loaded before all requirements were hooked, waiting on " .. requirementName)
			repeat
				requirementAdded.Event:wait()
			until requirements[requirementName]
			requirement = requirements[requirementName]
		end

		coroutine.wrap(function()
			requirement.callback(player)

			local requirementModel = Instance.new("Model")
			requirementModel.Name = requirement.name
			requirementModel.Parent = LoadRequirements

			print(requirement.name .. " loaded for " .. player.Name .. ".")

			if #LoadRequirements:GetChildren() == requirementsNeeded then
				coroutine.resume(running)
			end
		end)()
	end

	coroutine.yield()

	print(player.Name, "has finished loading.")

	if player.Parent then
		player:LoadCharacter()

		local loaded = Instance.new("Model")
		loaded.Name = "LoadRequirementsFilled"
		loaded.Parent = player
	end
end)

return LoadRequirement
