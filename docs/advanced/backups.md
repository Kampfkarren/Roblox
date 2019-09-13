!!! info
	This page is not to be confused with the [ordered backups](../saving_methods/) method of saving. This page is relevant no matter what saving method you choose.

DataStore2 in the end always uses Roblox's data stores and servers. Not infrequently, these servers will go down through no fault of you. You need to be prepared for when this happens. Luckily, DataStore2 makes it easy.

Let's say we have the following code:
```lua
local coinsStore = DataStore2("coins", player)
print(coinsStore:Get(0))
```

By default, if data stores are down, DataStore2 will keep retrying until it gets a result. However, we may not want it to do that! If you write:
```lua
local coinsStore = DataStore2("coins", player)
coinsStore:SetBackup(5)
print(coinsStore:Get(0))
```

...then DataStore2 will try to get the data five times before giving up.

When DataStore2 "gives up", it'll pretend the player doesn't have any data at all. Thus, no matter how many coins the player has, since there's no way to recover that data it'll simply print they have 0 coins.

However, don't worry! DataStore2 will mark this data store as a "backup data store". That means that **it will never save**. You wouldn't want it to save, it would override the player's actual data!

If it's necessary, you can check if a data store is a backup data store with the `:IsBackup()` method.

```lua
local coinsStore = DataStore2("coins", player)
coinsStore:SetBackup(5)
print(coinsStore:IsBackup()) -- will print "true" if DataStore2 couldn't successfully get the data
```

You can also clear a backup data store so that the next time you :Get(), DataStore2 will try to recover the data again. You do not need to reset the retry amount.

```lua
coinsStore:ClearBackup()
```
