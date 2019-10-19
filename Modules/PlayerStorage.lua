local ServerStorage = game:GetService("ServerStorage")

local PlayerStorage = ServerStorage.PlayerStorage

return function(player)
	local playerStorage = player:WaitForChild("PlayerGui"):FindFirstChild("PlayerStorage")

	if not playerStorage then
		playerStorage = PlayerStorage:Clone()
		playerStorage.Parent = player.PlayerGui
	end

	return playerStorage
end
