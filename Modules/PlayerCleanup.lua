local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Maid = require(ReplicatedStorage.Libraries.Maid)

return function(instance, player)
	local maid = Maid.new()
	if instance then
		maid:GiveTask(instance)
	end

	if player.Character then
		maid:GiveTask(player.Character.Humanoid.Died:connect(function()
			maid:DoCleaning()
		end))

		maid:GiveTask(player.CharacterAdded:connect(function()
			maid:DoCleaning()
		end))
	end

	if typeof(instance) == "Instance" then
		maid:GiveTask(instance.AncestryChanged:connect(function()
			if not instance:IsDescendantOf(game) then
				maid:DoCleaning()
			end
		end))
	end

	maid:GiveTask(player.AncestryChanged:connect(function()
		if player:IsDescendantOf(game) then
			maid:DoCleaning()
		end
	end))

	return maid
end
