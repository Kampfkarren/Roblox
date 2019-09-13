!!! bug
	Deserialization is known to cause issues with combined data stores. If you can reproduce these issues, please [file an issue on GitHub](https://github.com/Kampfkarren/Roblox/issues)!

Data stores have a limit on how much they can save. While usually it doesn't matter, sometimes you're expecting to be saving a LOT of data, and you're going to want to save as little as possible. However, it's rare that the most optimal way to store data will be the most readable. Luckily, DataStore2 can help make this process invisible, so you save the most optimal form of your data while using the most readable.

The process of saving data in an optimal, compressed format is called "serialization". Likewise, the process of taking compressed data and turning it into a format for humans is called "deserialization".

### Methods

DataStore2 lets you easily serialize/deserialize data with `BeforeInitialGet` and `BeforeSave`. Simply put, `BeforeInitialGet` defines your deserializer, while `BeforeSave` defines your serializer. Here's how it works.

Let's say we have an inventory system where a player can only have one of any item. Let's also suppose their data is saved like this:

```lua
{
	["Cool Sword"] = true,
	["Doge Head"] = true,
	-- etc...
}
```

However, we run into an issue. The more items we add, the more data we have to save, and we might have some pretty long names in the future!

```lua
["The Totally Awesome Sword of Justice, Sponsored By Builderman"] = true,
```

Ouch. Let's use serializers and deserializers to fix this. The best way to store our data is like this:

```lua
{ 1, 6, 8 }
```

Huh? Numbers? Yep, but those numbers are going to correlate to items. We're going to create a dictionary of all the items in our game under the name "ItemsDictionary". It'll map **item IDs** to **names**.

```lua
return {
	"Cool Sword",
	"Crazy Sword",
	"Doge Head",
	-- etc
}
```

Now, we can write our serializer and deserializer. We're going to save as numbers, but come back the same place we were before.
```lua
local itemsStore = DataStore2("items", player)

itemStore:BeforeInitialGet(function(serialized)
	-- BeforeInitialGet is called the first time :Get() is, known as the "initial get".
	-- This is the only time DataStore2 will call the DataStoreService get method.
	-- The "serialized" argument is the value that was actually in the store.
	-- That means that right now, it's something like { 1, 6, 8 }
	-- What we return is what DataStore2 is going to give `:Get()`.
	local deserialized = {}

	for _, id in pairs(serialized) do
		local itemName = ItemsDictionary[id]
		deserialized[itemName] = true
	end

	return deserialized
end)

itemStore:BeforeSave(function(deserialized)
	-- BeforeSave is called, well, before we save!
	-- The return is what DataStore2 will actually save, so we want it in the serialized form.
	local serialized = {}

	for itemName in pairs(deserialized) do
		for itemId, name in pairs(ItemsDictionary) do
			if name == itemName then
				table.insert(serialized, itemId)
			end
		end
	end

	return serialized
end)
```
