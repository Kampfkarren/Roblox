## Global Methods
### DataStore2
```
DataStore2(dataStoreName, player) -> DataStore
```

Will create a [DataStore](#datastore-api) instance for the player with that specific name. If one already exists, will retrieve that one.

!!! warning
	Do not use the master key that you use in combined data stores, this behavior is not defined!

### DataStore2.Combine
```
DataStore2.Combine(masterKey, ...keysToCombine)
```

Combines all the keys under `keysToCombine` under the `masterKey`. Internally, will save all data under those keys into the `masterKey` as one large dictionary. You can learn more about combined data stores and why you should use them in the [gotchas page](../guide/gotchas/). Can be called multiple times without overriding previously combined keys.

!!! warning
	You should never use data stores without combining them or at the very least, replicating the behavior by creating one large dictionary yourself! Combined data stores will [soon be the default way to use DataStore2](https://github.com/Kampfkarren/Roblox/issues/38).

### DataStore2.ClearCache
```
DataStore2.ClearCache()
```

Clears the DataStore2 cache, so using `DataStore2` again will give you fresh data stores. This is mostly for internal use or for unit testing.

### DataStore2.PatchGlobalSettings
```
DataStore2.PatchGlobalSettings({
	SavingMethod?: "Standard" | "OrderedBackups",
})
```

Will override the global settings by patching it with ones you provide. This means if you do not specify a setting, it will not be changed.

#### Current Settings
- SavingMethod (Default: "OrderedBackups")
	- Controls how the data should be saved. Read more in the [saving methods page](../advanced/saving_methods).

### DataStore2.SaveAll
```
DataStore2.SaveAll(player)
```

Will save all the data stores of the player. This is the recommended way to save combined data stores.

## DataStore API

### DataStore:Get
```
Get(defaultValue?: any, dontAttemptGet?: bool) -> any
```

Will return the value cached in the data store, if it exists. If it does not exist, will then attempt to get the value from Roblox data stores. This function will only yield if there is no value in the data store.

When a `defaultValue` is passed in, that value will be used if the player has no data.

When `dontAttemptGet` is `true`, will return the cached value and will not attempt to get it from Roblox if it does not exist. Ignores the value of `defaultValue`.

!!! note
	:Get() returns a deep copy of whatever the data is, thus if the value is a table, then `dataStore:Get() ~= dataStore:Get()`. This may be lifted in the future for "pure" data stores.

### DataStore:Set
```
Set(newValue: any)
```

Will set the cached value in the data store to `newValue`. Does not make any data store calls, and so will never yield.

### DataStore:Save
```
Save()
```

Saves the data in the current data store to Roblox. This function yields.

!!! warning
	Currently, Save() does not attempt to retry if it fails the first time. Save() *can* error if data stores are down or your data is invalid.

### DataStore:Update
```
Update(updateCallback: (any) => any)
```

Will set the data store value to the return of `updateCallback` when passed with the current value.

!!! bug
	`Update` currently does not attempt to get the value from the Roblox data store. [This will be fixed in a future update.](https://github.com/Kampfkarren/Roblox/issues/57)

!!! notice
	You may see people talk about how `UpdateAsync` is more reliable than `SetAsync` in normal Roblox data stores. In DataStore2, this doesn't matter since neither actually call Roblox data store methods, so use `:Set` when you don't need the old value.

### DataStore:GetTable
```
GetTable(default: Dictionary<any, any>) -> Dictionary<any, any>
```

Will get the value (either from the cache or Roblox data stores), and patch it with the default value if it doesn't have the keys. For example, if you have the data:

```lua
{
	coins = 0,
	swords = {},
}
```

...and want to add a `gems` field, just appending on that to the default value for [`Get`](#datastoreget) won't work the way you might want it too--it won't add the key!

```lua
-- Oops! The player already has data, so it doesn't try to use the default value!
dataStore:Get({
	coins = 0,
	gems = 0,
	swords = {},
})
```

You can, however, use `GetTable`:

```lua
-- Much better! It'll check if they have each key rather than just if they have data.
dataStore:GetTable({
	coins = 0,
	gems = 0,
	swords = {},
})
```

!!! note
	This is not necessary to use tables with DataStore2. You can save/retrieve tables just like any other piece of data.

### DataStore:Increment
```
Increment(add: number, defaultValue?: number)
```

Will increment the current value (cached or from Roblox data stores) with the value provided in `add`. If a value does not exist, will use `defaultValue`, then add.

### DataStore:OnUpdate
```
OnUpdate(callback: (value: any) => void)
```

Will call the callback provided whenever the cached value is updated. Is *not* called on the initial get.

### DataStore:SetBackup
```
SetBackup(retries: number, alternativeDefaultValue?: any)
```

Will set the number of retries for `:Get()` to attempt to retrieve a Roblox data store value before giving up and marking the data store as a backup. If `alternativeDefaultValue` is provided, then that value will be given to `:Get()`, otherwise normal rules apply while assuming the player actually doesn't have any data. Learn more on the [backups page](../advanced/backups/).

### DataStore:IsBackup
```
IsBackup() -> bool
```

Returns whether the current data store is a backup data store or not. Learn more on the [backups page](../advanced/backups/).

!!! tip
	You don't need to know if a data store is a backup when [saving](#datastoresave). Backup data stores will never save.

### DataStore:ClearBackup
```
ClearBackup()
```

Unmarks the current data store as a backup data store. The next time `Get()` is called, it'll attempt to get the value inside Roblox data stores again. Learn more on the [backups page](../advanced/backups/).

### DataStore:BeforeInitialGet
```
BeforeInitialGet(modifier: (dataValue: any) => any)
```

Called after a value is received from Roblox data stores. The value returned is what `:Get()` will receive. Primarily used for deserialization. Learn more on the [serialization page](../advanced/serde/).

!!! bug
	BeforeInitialGet is known to cause issues with combined data stores. If you can reproduce these issues, please [file an issue on GitHub](https://github.com/Kampfkarren/Roblox/issues)!


### DataStore:BeforeSave
```
BeforeSave(modifier: (dataValue: any) => any)
```

Called before a value is saved into Roblox data stores. The value returned is what will be saved. Primarily used for serialization. Learn more on the [serialization page](../advanced/serde/).

### DataStore:AfterSave
```
AfterSave(callback: (savedValue: any) => void)
```

Will call the callback after data is successfully saved into Roblox data stores.

### DataStore:GetAsync
```
GetAsync(defaultValue?: any, dontAttemptGet?: bool) -> Promise<any>
```

Same as [`Get`](#datastoreget), but will instead return a [`Promise`](https://eryn.io/roblox-lua-promise/) instead of yielding.

### DataStore:SaveAsync
```
SaveAsync() -> Promise<bool, any>
```

Same as [`Save`](#datastoresave), but will instead return a [`Promise`](https://eryn.io/roblox-lua-promise/) instead of yielding. On rejection, will return the error that caused the reject. On resolution, will return whether the data *actually* saved. This is false in the case of being in studio, data not being updated or the data store being a backup store.

!!! tip
	If you only want to be notified when the data is truly saved, use [`AfterSave`](#datastoreaftersave).

### DataStore:GetTableAsync
```
GetTableAsync(default: Dictionary<any, any>) -> Promise<Dictionary<any, any>>
```

Same as [`GetTable`](#datastoregettable), but will instead return a [`Promise`](https://eryn.io/roblox-lua-promise/) instead of yielding.

### DataStore:IncrementAsync
```
IncrementAsync(add: number, defaultValue?: number) -> Promise<void>
```

Same as [`Increment`](#datastoreincrement), but will instead return a [`Promise`](https://eryn.io/roblox-lua-promise/) instead of yielding.
