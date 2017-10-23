--requires PlayerStorage module, and a folder titled LoadRequirements in the PlayerStorage folder
local PlayerStorage = require(game:GetService("ServerScriptService").PlayerStorage)
local requirements = {}
local LoadRequirement = {}
local server = game:GetService("RunService"):IsServer()

function LoadRequirement:AddRequirement(requirementName, requirementCallback)
	local model = Instance.new("Model")
	model.Name = requirementName
	model.Parent = game:GetService("ServerStorage").PlayerStorage.LoadRequirements
	
	table.insert(requirements, {
		name = requirementName,
		callback = requirementCallback
	})
end

game:GetService("Players").PlayerAdded:connect(function(player)
	game:GetService("RunService").Stepped:wait()
	
	local LoadRequirements = PlayerStorage(player).LoadRequirements
	
	for _,requirement in pairs(requirements) do
		spawn(function()
			requirement.callback(player)
			
			LoadRequirements:WaitForChild(requirement.name):Destroy()
			
			if server then --why do i have this i forget
				print(requirement.name .. " loaded.")
			end
		end)
	end
	
	--this is weird
	while #LoadRequirements:GetChildren() > 0 do
		LoadRequirements.ChildRemoved:wait()
	end
	
	if player.Parent then
		player:LoadCharacter()
	end
end)

return LoadRequirement
