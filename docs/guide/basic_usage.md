DataStore2 is meant to be easy to use. The basic usage can be seen from the following example code.

The code below does the following:
- Fires a remote event called "CoinAmount" to players when they join and when their amount of coins updates.
- Listens for a "BuyProduct" remote to let players buy products.
- Buying products reduces their amount of coins, which will then fire the remote event.

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local DataStore2 = require(ServerScriptService.DataStore2)

-- Always "combine" any key you use! To understand why, read the "Gotchas" page.
DataStore2.Combine("DATA", "coins")

Players.PlayerAdded:Connect(function(player)
	local coinStore = DataStore2("coins", player)

	local function callRemote(value)
		ReplicatedStorage.CoinAmount:FireClient(player, value)
	end

	-- Fire a remote event to the player telling them how many coins they have.
	-- If this is their first time playing the game, they'll start out with 100.
	callRemote(coinStore:Get(100))

	-- Everytime the coin store updates, we'll send the RemoteEvent again.
	coinStore:OnUpdate(callRemote)
end)

-- This is a RemoteEvent where a player can purchase a product by its name.
local Products = require(ReplicatedStorage.Products)

ReplicatedStorage.BuyProduct.OnServerEvent:connect(function(player, productName)
	if not Products[productName] then return end -- Make sure the player is buying a real product

	local coinStore = DataStore2("coins", player)
	local productPrice = Products[productName].price

	if coinStore:Get(100) >= productPrice then
		print("Buying product", productName)
		coinStore:Increment(-productPrice)
	end
end)
```
