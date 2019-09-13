DataStore2 supports two ways of storing data. You can tell DataStore2 which one to use by either editing the `Settings` module inside DataStore2, or by running the following command before creating any data stores:

```lua
DataStore2.PatchGlobalSettings({
	SavingMethod = "SavingMethodGoesHere",
})
```

## "OrderedBackups"

This is the default setting for DataStore2, and is partly responsible for its popularity. With this as the saving method, DataStore2 will use *multiple data stores* instead of just one. This ensures no data is lost, but is extremely redundant and uses a lot of storage on Roblox's side. This method was initially conceptualized by berezaa, which is why you'll sometimes hear this coloquially called the "berezaa method".

## "Standard"

While this is the saving method, DataStore2 will instead just use normal data stores without any funny business. This is the recommended saving method if you are migrating an existing game to DataStore2.

For example, if you use the key "coins" (assuming it's uncombined), DataStore2 will get your data simply with:

```lua
DataStoreService:GetDataStore("coins"):GetAsync(player.UserId)
```
