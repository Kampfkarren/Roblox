return function()
	local DataStoreService = game:GetService("DataStoreService")

	local DataStore2 = require(script:FindFirstAncestor("Root").Modules.DataStore2)

	local BIND_TO_CLOSE = game.BIND_TO_CLOSE
	local PLAYER_REMOVING = game.PLAYER_REMOVING

	local function equals(t1, t2)
		for key, value in pairs(t1) do
			if t2[key] ~= value then
				return false
			end
		end

		for key, value in pairs(t2) do
			if t1[key] ~= value then
				return false
			end
		end

		return true
	end

	local fakePlayer = {}
	fakePlayer.UserId = 156
	setmetatable(fakePlayer, {
		TYPEOF_HACK = "Instance",
	})

	local function test(DataStore2, save)
		return function()
			it("should return whatever the data store value is the first time", function()
				expect(DataStore2(UUID(), fakePlayer):Get()).to.equal(nil)

				local nonNilKey = UUID()
				save(nonNilKey, "abc")
				expect(DataStore2(nonNilKey, fakePlayer):Get()).to.equal("abc")
			end)

			it("should use default values", function()
				expect(DataStore2(UUID(), fakePlayer):Get("abc")).to.equal("abc")

				local nonNilKey = UUID()
				save(nonNilKey, "abc")
				expect(DataStore2(nonNilKey, fakePlayer):Get("badDefault")).to.equal("abc")
			end)

			it("should set", function()
				local dataStore = DataStore2(UUID(), fakePlayer)
				dataStore:Set(1)
				expect(dataStore:Get()).to.equal(1)
			end)

			it("should save", function()
				local key = UUID()
				local dataStore = DataStore2(key, fakePlayer)
				dataStore:Set(1)
				dataStore:Save()

				DataStore2.ClearCache()
				local dataStore = DataStore2(key, fakePlayer)
				expect(dataStore:Get()).to.equal(1)
			end)

			it("should save when the player leaves", function()
				local key = UUID()
				local dataStore = DataStore2(key, fakePlayer)
				dataStore:Set(1)
				PLAYER_REMOVING:Fire(fakePlayer)

				DataStore2.ClearCache()
				local dataStore = DataStore2(key, fakePlayer)
				expect(dataStore:Get()).to.equal(1)
			end)

			it("should not deserialize if value is nil", function()
				local dataStore = DataStore2(UUID(), fakePlayer)
				dataStore:BeforeInitialGet(function()
					return "deserialized"
				end)
				expect(dataStore:Get()).to.equal(nil)
			end)

			it("should not deserialize if value was nil and then set later", function()
				local dataStore = DataStore2(UUID(), fakePlayer)
				dataStore:BeforeInitialGet(function()
					return "deserialized"
				end)
				expect(dataStore:Get()).to.equal(nil)
				dataStore:Set("doge")
				expect(dataStore:Get()).to.equal("doge")
			end)

			it("should deserialize with a non-nil value", function()
				local key = UUID()
				save(key, 1)
				local dataStore = DataStore2(key, fakePlayer)
				dataStore:BeforeInitialGet(function(value)
					return value + 1
				end)
				expect(dataStore:Get()).to.equal(2)
				expect(dataStore:Get()).to.equal(2)
			end)

			it("should serialize", function()
				local key = UUID()
				local dataStore = DataStore2(key, fakePlayer)
				dataStore:BeforeSave(string.upper)
				dataStore:Set("abc")
				dataStore:Save()

				DataStore2.ClearCache()
				local dataStore = DataStore2(key, fakePlayer)
				expect(dataStore:Get()).to.equal("ABC")
			end)

			it("should call AfterSave", function()
				local called = false
				local dataStore = DataStore2(UUID(), fakePlayer)
				dataStore:Set("a")
				dataStore:AfterSave(function()
					called = true
				end)
				dataStore:Save()
				expect(called).to.equal(true)
			end)

			it("should give default values for GetTable", function()
				local key = UUID()

				local dataStore = DataStore2(key, fakePlayer)
				expect(equals(
					dataStore:GetTable({ foo = 1 }),
					{ foo = 1 }
				))
				dataStore:Set({ foo = 2 })
				dataStore:Save()

				DataStore2.ClearCache()
				local dataStore = DataStore2(key, fakePlayer)

				expect(equals(
					dataStore:GetTable({ foo = 1 }),
					{ foo = 2 }
				))

				expect(equals(
					dataStore:GetTable({ foo = 1, bar = 2 }),
					{ foo = 2, bar = 2 }
				))
			end)

			it("should not conflict multiple data stores", function()
				local key1, key2 = UUID(), UUID()

				local dataStore1 = DataStore2(key1, fakePlayer)
				local dataStore2 = DataStore2(key2, fakePlayer)

				dataStore1:Set(10)
				dataStore2:Set(20)

				dataStore1:Save()
				dataStore2:Save()

				DataStore2.ClearCache()

				local dataStore1 = DataStore2(key1, fakePlayer)
				local dataStore2 = DataStore2(key2, fakePlayer)

				expect(dataStore1:Get()).to.equal(10)
				expect(dataStore2:Get()).to.equal(20)
			end)

			-- Combined data stores had a problem with this
			it("should not conflict multiple BeforeSave", function()
				local key1, key2 = UUID(), UUID()

				local dataStore1 = DataStore2(key1, fakePlayer)
				dataStore1:BeforeSave(function(value)
					return value + 1
				end)

				-- lol dataStore2
				local dataStore2 = DataStore2(key2, fakePlayer)
				dataStore2:BeforeSave(function(value)
					return value - 1
				end)

				dataStore1:Set(10)
				dataStore2:Set(20)
				expect(dataStore1:Get()).to.equal(10)
				expect(dataStore2:Get()).to.equal(20)

				dataStore1:Save()
				dataStore2:Save()

				DataStore2.ClearCache()

				local dataStore1 = DataStore2(key1, fakePlayer)
				local dataStore2 = DataStore2(key2, fakePlayer)

				expect(dataStore1:Get()).to.equal(11)
				expect(dataStore2:Get()).to.equal(19)
			end)

			it("should work in conjuction with both BeforeInitialGet and BeforeSave", function()
				local key = UUID()
				save(key, 10)
				local dataStore = DataStore2(key, fakePlayer)

				dataStore:BeforeInitialGet(function(value)
					return value - 1
				end)

				dataStore:BeforeSave(function(value)
					return value * 2
				end)

				expect(dataStore:Get()).to.equal(9)
				dataStore:Set(11)
				dataStore:Save() -- Saves as 22
				dataStore:Save() -- Still 22

				DataStore2.ClearCache()
				local dataStore = DataStore2(key, fakePlayer)
				dataStore:BeforeInitialGet(function(value)
					return value - 1
				end)
				expect(dataStore:Get()).to.equal(21)
			end)

			it("should call OnUpdate callbacks", function()
				local key1, key2 = UUID(), UUID()
				local timesCalled1, timesCalled2 = 0, 0

				local dataStore1 = DataStore2(key1, fakePlayer)
				dataStore1:OnUpdate(function()
					timesCalled1 = timesCalled1 + 1
				end)

				local dataStore2 = DataStore2(key2, fakePlayer)
				dataStore2:OnUpdate(function()
					timesCalled2 = timesCalled2 + 1
				end)

				expect(timesCalled1).to.equal(0)
				expect(timesCalled2).to.equal(0)
				dataStore1:Get(10) -- :Get should NOT trip OnUpdate
				expect(timesCalled1).to.equal(0)
				expect(timesCalled2).to.equal(0)
				dataStore1:Set(10)
				expect(timesCalled1).to.equal(1)
				expect(timesCalled2).to.equal(0)
				dataStore2:Set(20)
				expect(timesCalled1).to.equal(1)
				expect(timesCalled2).to.equal(1)
			end)

			it("should not call OnUpdate when using :Get() with a default value", function()
				local dataStore = DataStore2(UUID(), fakePlayer)
				local called = false
				dataStore:OnUpdate(function()
					called = true
				end)
				dataStore:Get(true)
				expect(called).to.equal(false)
			end)

			it("should call OnUpdate when using :GetTable() with a default value that didn't have the keys before", function()
				local dataStore = DataStore2(UUID(), fakePlayer)
				local called = false
				dataStore:OnUpdate(function()
					called = true
				end)
				dataStore:Get({})
				dataStore:GetTable({ Doge = "funny" })
				expect(called).to.equal(true)
			end)

			it("should not call OnUpdate when using :GetTable() with a default value that had all keys before", function()
				local dataStore = DataStore2(UUID(), fakePlayer)
				local called = false
				dataStore:OnUpdate(function()
					called = true
				end)
				dataStore:Get({ Doge = "funny" })
				expect(dataStore:GetTable({ Doge = "hysterical" }).Doge).to.equal("funny")
				expect(called).to.equal(false)
			end)

			it("should use backups when data stores fail", function()
				local key = UUID()
				save(key, "backup test")

				game.SET_ERROR_RATE:Fire(1)
				local errorInfo = {pcall(function()
					local dataStore = DataStore2(key, fakePlayer)
					dataStore:SetBackup(5)
					expect(dataStore:Get("oh no")).to.equal("oh no")
				end)}
				game.SET_ERROR_RATE:Fire(0)

				assert(unpack(errorInfo))
			end)
		end
	end

	local function save(key, value)
		local dataKey = key .. "/" .. fakePlayer.UserId
		local dataStore = DataStoreService:GetDataStore(dataKey)
		local orderedDataStore = DataStoreService:GetOrderedDataStore(dataKey)

		local timeKey = os.time()
		dataStore:SetAsync(timeKey, value)
		orderedDataStore:SetAsync(timeKey, timeKey)
	end

	describe("normal data stores", test(DataStore2, save))

	local fakeDataStore = setmetatable({}, {
		__call = function(_, key, player)
			DataStore2.Combine("DATA", key)
			return DataStore2(key, player)
		end,
		__index = DataStore2,
	})

	describe("combined data stores", test(fakeDataStore, function(key, value)
		local store = DataStore2("DATA", fakePlayer)
		store:ClearBackup()
		local combinedValue = store:Get({})
		combinedValue[key] = value
		store:Save()
		DataStore2.ClearCache()
	end))

	describe("combined data stores specific functionality", function()
		it("should call BeforeSave on every data store when calling :Save() on one", function()
			local key1, key2 = UUID(), UUID()
			DataStore2.Combine(UUID(), key1, key2)
			local called1, called2 = 0, 0

			local store1 = DataStore2(key1, fakePlayer)
			store1:BeforeSave(function(value)
				called1 = called1 + 1
				return value
			end)
			store1:Set(1)

			local store2 = DataStore2(key2, fakePlayer)
			store2:BeforeSave(function(value)
				called2 = called2 + 1
				return value
			end)
			store2:Set(1)

			expect(called1).to.equal(0)
			expect(called2).to.equal(0)
			store1:Save()
			expect(called1).to.equal(1)
			expect(called2).to.equal(1)
		end)
	end)
end