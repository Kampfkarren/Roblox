--expects a folder in ServerStorage titled PlayerStorage
local PlayerStorage = game:GetService("ServerStorage").PlayerStorage

return function(player)
	local playerStorage = player:WaitForChild("PlayerGui"):FindFirstChild("PlayerStorage")
	
	if not playerStorage then
		playerStorage = PlayerStorage:Clone()
		playerStorage.Parent = player.PlayerGui
	end
	
	return playerStorage
end
