- You need to set your data stores *as they change*, not on PlayerRemoving.

The normal way of doing data stores is to keep a cache somewhere of a player's data (such as in a folder or using leaderstats), then saving when the player leaves. **It is wrong, however, to use DataStore2 this way**. DataStore2 is built to be used whenever your data actually changes. You shouldn't invoke DataStore2 in PlayerRemoving *at all*. Don't worry, `:Set` will never error or do API calls, it's all cached. DataStore2 will save the player's data before they leave.

- Because of the throttles on OrderedDataStores, DataStore2 (with the default saving method) is only guaranteed to not throttle on :Get() if you use less than 2 unique keys.

In normal data stores, you'd save all your data into one giant player data table to minimize data loss/throttling. In DataStore2, this is a built in feature! Simply use `DataStore2.Combine("DATA", "any", "keys", "here")`, or call it multiple times (`DataStore2.Combine("DATA", "coins"); DataStore2.Combine("DATA", "guns")`).

These are called "combined data stores", they save all your data into one big table but without the cost of ergonomics (you don't have to get the entire data just to manipulate one part of it).

The "DATA" is what the data will combine under internally. If you are migrating an existing game (and have made sure to set your [saving method](../advanced/saving_methods/) to Standard), this will be whatever your large data table is already called.

In the future, combined data stores will become the default, but for now you must explicitly define every key you use, or be at risk of heavy throttling.
