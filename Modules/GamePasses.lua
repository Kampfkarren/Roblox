local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local WeakInstanceTable = require(ReplicatedStorage.Libraries.WeakInstanceTable)

local FreeGamePasses = ReplicatedStorage:FindFirstChild("FreeGamePasses")
local freeGamePasses = FreeGamePasses and FreeGamePasses.Value and RunService:IsStudio()

local boughtGamePasses = WeakInstanceTable()

local listeningPasses = {}

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, purchased)
	if not purchased then return end
	boughtGamePasses[player] = boughtGamePasses[player] or {}
	boughtGamePasses[player][gamePassId] = true
end)

local GamePasses = {}

local function userOwnsGamePassAsync(player, gamePassId)
	local success, doesOwn = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, gamePassId)
	return success and doesOwn or false
end

function GamePasses.ListenForPass(gamePassId)
	if listeningPasses[gamePassId] then return end
	listeningPasses[gamePassId] = true

	local function checkGamePassOwnership(player)
		boughtGamePasses[player] = boughtGamePasses[player] or {}
		boughtGamePasses[player][gamePassId] = userOwnsGamePassAsync(player, gamePassId)
	end

	if RunService:IsServer() then
		Players.PlayerAdded:Connect(checkGamePassOwnership)
		for _, player in ipairs(Players:GetPlayers()) do
			local thread = coroutine.create(checkGamePassOwnership)
			coroutine.resume(thread, player)
		end
	else
		local thread = coroutine.create(checkGamePassOwnership)
		coroutine.resume(thread, Players.LocalPlayer)
	end
end

function GamePasses.PlayerOwnsPass(player, gamePassId)
	boughtGamePasses[player] = boughtGamePasses[player] or {}
	return freeGamePasses or not not boughtGamePasses[player][gamePassId]
end

return GamePasses
