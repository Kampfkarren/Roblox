# Changelog
All notable changes to this project will be documented in this file.

This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
- Added `DataStore2.SaveAllAsync`.
- Fix `:IncrementAsync` throwing an error on combined data stores.
- Fix `:Set` on combined data stores having the potential to yield.
- Fix a crash relating to backups.
- Fix `GetTable` not working appropriately when using different default table keys.
- Fix `GetTable` not working appropriately when using combined data stores.
- Fix `:IncrementAsync` not returning a Promise

## [1.3.0]
- Added :GetAsync(), :GetTableAsync, and :IncrementAsync(), which are [promise](https://github.com/evaera/roblox-lua-promise) versions of their non-async counterparts.
- :SaveAsync() now returns a promise.
- If data can't save when a player leaves, it'll no longer halt Studio.
- Added a Settings module and `DataStore2.PatchGlobalSettings` to manipulate settings of DataStore2.
- Added a setting (SavingMethod) for using standard data stores instead of the berezaa method. It can currently be set to "OrderedBackups" (the default) or "Standard".