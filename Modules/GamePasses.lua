local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local WeakInstanceTable = require(ReplicatedStorage.Libraries.WeakInstanceTable)

local FreeGamePasses = ReplicatedStorage:FindFirstChild("FreeGamePasses")
local freeGamePasses = FreeGamePasses and FreeGamePasses.Value and RunService:IsStudio()

local boughtGamePasses = WeakInstanceTable()

local listeningPasses = {}

MarketplaceService.PromptGamePassPurchaseFinished:connect(function(player, gamePassId, purchased)
	if not purchased then return end
	boughtGamePasses[player] = boughtGamePasses[player] or {}
	boughtGamePasses[player][gamePassId] = true
end)

local GamePasses = {}

function GamePasses.ListenForPass(gamePassId)
	if listeningPasses[gamePassId] then return end
	listeningPasses[gamePassId] = true

	local function checkGamePassOwnership(player)
		boughtGamePasses[player] = boughtGamePasses[player] or {}
		boughtGamePasses[player][gamePassId] = MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamePassId)
	end

	if RunService:IsServer() then
		Players.PlayerAdded:connect(checkGamePassOwnership)
		for _, player in pairs(Players:GetPlayers()) do
			coroutine.wrap(checkGamePassOwnership)(player)
		end
	else
		coroutine.wrap(checkGamePassOwnership)(Players.LocalPlayer)
	end
end

function GamePasses.PlayerOwnsPass(player, gamePassId)
	boughtGamePasses[player] = boughtGamePasses[player] or {}
	return freeGamePasses or not not boughtGamePasses[player][gamePassId]
end

return GamePasses

