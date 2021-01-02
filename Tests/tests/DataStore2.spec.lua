return function()
	local HttpService = game:GetService("HttpService")
	local RunService = game:GetService("RunService")
	local ServerScriptService = game:GetService("ServerScriptService")

	local moduleDataStore2 = ServerScriptService.Modules.DataStore2

	local MockDataStoreServiceConstants = require(
		ServerScriptService
			.Tests
			.MockDataStoreService
			.MockDataStoreService
			.MockDataStoreConstants
	)

	MockDataStoreServiceConstants.BUDGETING_ENABLED = false
	MockDataStoreServiceConstants.LOGGING_ENABLED = false
	MockDataStoreServiceConstants.WRITE_COOLDOWN = 0
	MockDataStoreServiceConstants.YIELD_TIME_MAX = 0

	local MockDataStoreService = require(ServerScriptService.Tests.MockDataStoreService)

	local playerRemovingEvent = Instance.new("BindableEvent")

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

	local function UUID()
		return HttpService:GenerateGUID()
	end

	local fakePlayer = {}
	fakePlayer.AncestryChanged = playerRemovingEvent.Event
	fakePlayer.IsDescendantOf = function()
		return false
	end
	fakePlayer.UserId = 156

	require(moduleDataStore2.IsPlayer).Check = function(object)
		return object == fakePlayer
	end

	require(moduleDataStore2.DataStoreServiceRetriever).Get = function()
		return MockDataStoreService
	end

	local DataStore2 = require(moduleDataStore2)

	local function test(DataStore2, save)
		return function()
			HACK_NO_XPCALL()

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

			it("should validate Set", function()
				local dataStore = DataStore2(UUID(), fakePlayer)

				local function testValidator(dataToValidate)
					if dataToValidate == "yepp" then
						return true
					elseif dataToValidate == "definitelyNot" then
						return false, "A validation error message"
					end

					return false
				end

				dataStore:SetValidator(testValidator)
				expect(dataStore:Set("nope")).to.throw("Attempted to set data store to an invalid value during :Set")
				expect(dataStore:Set("definitelyNot")).to.throw("A validation error message")
				expect(dataStore:Set("yepp")).to.be.ok()
			end)

			it("should validate Update", function()
				local dataStore = DataStore2(UUID(), fakePlayer)

				local function testValidator(dataToValidate)
					if dataToValidate == "yepp" then
						return true
					elseif dataToValidate == "definitelyNot" then
						return false, "A validation error message"
					end

					return false
				end

				dataStore:SetValidator(testValidator)

				expect(dataStore:Update(function()
					return "nope"
				end)).to.throw("Attempted to set data store to an invalid value during :Update")

				expect(dataStore:Update(function()
					return "definitelyNot"
				end)).to.throw("A validation error message")

				expect(dataStore:Update(function()
					return "yepp"
				end)).to.be.ok()
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
				playerRemovingEvent:Fire()

				-- Give Promise.async time to resolve
				RunService.Heartbeat:wait()
				RunService.Heartbeat:wait()

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

			it("should not conflict multiple BeforeInitialGet", function()
				local key1, key2, key3 = UUID(), UUID(), UUID()

				local dataStore1 = DataStore2(key1, fakePlayer)
				local dataStore2 = DataStore2(key2, fakePlayer)
				local dataStore3 = DataStore2(key3, fakePlayer)

				dataStore1:Set(1)
				dataStore2:Set(3)
				dataStore3:Set(10)

				DataStore2.SaveAll(fakePlayer)
				DataStore2.ClearCache()

				local dataStore1 = DataStore2(key1, fakePlayer)

				dataStore1:BeforeInitialGet(function(x)
					return x + 1
				end)
				expect(dataStore1:Get()).to.equal(2)
				expect(dataStore1:Get()).to.equal(2)

				local dataStore2 = DataStore2(key2, fakePlayer)
				dataStore2:BeforeInitialGet(function(x)
					return x * 2
				end)
				expect(dataStore2:Get()).to.equal(6)
				expect(dataStore2:Get()).to.equal(6)

				expect(dataStore3:Get()).to.equal(10)
				expect(dataStore2:Get()).to.equal(6)
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

			it("should call OnUpdate callbacks when using Update", function()
				local dataStore = DataStore2(UUID(), fakePlayer)
				
				local timesCalled = 0
				dataStore:OnUpdate(function()
					timesCalled = timesCalled + 1
				end)

				dataStore:Update(function(oldValue)
					return (oldValue or 0) + 1
				end)

				expect(timesCalled).to.equal(1)
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

				MockDataStoreServiceConstants.SIMULATE_ERROR_RATE = 1

				local dataStore
				local errorInfo = {pcall(function()
					dataStore = DataStore2(key, fakePlayer)
					dataStore:SetBackup(5)
					expect(dataStore:Get("oh no")).to.equal("oh no")
				end)}
				MockDataStoreServiceConstants.SIMULATE_ERROR_RATE = 0
				dataStore:ClearBackup()

				assert(unpack(errorInfo))
			end)

			it("should call OnUpdate on increment", function()
				local dataStore = DataStore2(UUID(), fakePlayer)
				local called = false
				dataStore:OnUpdate(function()
					called = true
				end)
				dataStore:Get(0)
				dataStore:Increment(1)
				expect(called).to.equal(true)
			end)

			it("should not return an identical value for default values", function()
				local dataStore = DataStore2(UUID(), fakePlayer)
				local data = {}
				expect(dataStore:Get(data)).to.never.equal(data)
			end)

			it("should save all data stores when using SaveAll", function()
				local key1, key2, key3 = UUID(), UUID(), UUID()

				local dataStore1 = DataStore2(key1, fakePlayer)
				local dataStore2 = DataStore2(key2, fakePlayer)
				local dataStore3 = DataStore2(key3, fakePlayer)

				dataStore1:Set(1)
				dataStore2:Set(2)
				dataStore3:Set(3)

				DataStore2.SaveAll(fakePlayer)
				DataStore2.ClearCache()

				expect(dataStore1:Get()).to.equal(1)
				expect(dataStore2:Get()).to.equal(2)
				expect(dataStore3:Get()).to.equal(3)
			end)

			it("should not truly save after calling Save without updating", function()
				local dataStore = DataStore2(UUID(), fakePlayer)
				local timesCalled = 0

				dataStore:Get() -- HACK: #63

				dataStore:AfterSave(function()
					timesCalled = timesCalled + 1
				end)

				dataStore:Set(1)
				dataStore:Save()
				expect(timesCalled).to.equal(1)

				-- Data hasn't been updated
				dataStore:Save()
				expect(timesCalled).to.equal(1)

				-- Data has been updated, truly save
				dataStore:Set(2)
				dataStore:Save()
				expect(timesCalled).to.equal(2)

				dataStore:Save()
				expect(timesCalled).to.equal(2)
			end)

			-- it("should retry if data stores error once, but fix themselves later", function()
			-- 	local key = UUID()
			-- 	save(key, "foo")

			-- 	local testOver = false
			-- 	local testPassed = false

			-- 	MockDataStoreServiceConstants.SIMULATE_ERROR_RATE = 1
			-- 	MockDataStoreServiceConstants.YIELD_TIME_MAX = 0.1
			-- 	MockDataStoreServiceConstants.YIELD_TIME_MIN = 0.1

			-- 	delay(0.4, function()
			-- 		if not testOver then
			-- 			MockDataStoreServiceConstants.SIMULATE_ERROR_RATE = 0
			-- 			MockDataStoreServiceConstants.YIELD_TIME_MAX = 0
			-- 		end
			-- 	end)

			-- 	local running = coroutine.running()

			-- 	spawn(function()
			-- 		local dataStore = DataStore2(key, fakePlayer)
			-- 		expect(dataStore:Get()).to.equal("foo")
			-- 		testPassed = true
			-- 		if not testOver then
			-- 			coroutine.resume(running)
			-- 		end
			-- 	end)

			-- 	delay(1, function()
			-- 		if not testOver then
			-- 			coroutine.resume(running)
			-- 		end
			-- 	end)

			-- 	coroutine.yield()

			-- 	testOver = true
			-- 	MockDataStoreServiceConstants.SIMULATE_ERROR_RATE = 0
			-- 	MockDataStoreServiceConstants.YIELD_TIME_MAX = 0
			-- 	expect(testPassed).to.equal(true)

			-- 	assert(success, result)
			-- end)
		end
	end

	local function save(key, value)
		local dataKey = key .. "/" .. fakePlayer.UserId
		local dataStore = MockDataStoreService:GetDataStore(dataKey)
		local orderedDataStore = MockDataStoreService:GetOrderedDataStore(dataKey)

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
		HACK_NO_XPCALL()

		it("should call BeforeSave on every data store when calling :Save() on one", function()
			local key1, key2 = UUID(), UUID()
			DataStore2.Combine(UUID(), key1, key2)
			local called1, called2 = 0, 0

			local store1 = DataStore2(key1, fakePlayer)
			store1:Get() -- HACK: #63
			store1:BeforeSave(function(value)
				called1 = called1 + 1
				return value
			end)
			store1:Set(1)

			local store2 = DataStore2(key2, fakePlayer)
			store2:Get() -- HACK: #63
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
