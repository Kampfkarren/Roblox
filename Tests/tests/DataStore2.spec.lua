return function()
	local DataStoreService = game:GetService("DataStoreService")

	local DataStore2 = require(script:FindFirstAncestor("Root").Modules.DataStore2)

	local fakePlayer = {}
	fakePlayer.UserId = 156

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
				local dataStore = DataStore2(UUID(), fakePlayer)
				dataStore:Set(1)
				dataStore:Save()
				dataStore:ClearBackup()
				expect(dataStore:Get()).to.equal(1)
			end)

			it("should not deserialize if value is nil", function()
				local dataStore = DataStore2(UUID(), fakePlayer)
				dataStore:BeforeInitialGet(function()
					return "deserialized"
				end)
				expect(dataStore:Get()).to.equal(nil)
			end)

			it("should deserialize with a non-nil value", function()
				local key = UUID()
				save(key, "abc")
				local dataStore = DataStore2(key, fakePlayer)
				dataStore:BeforeInitialGet(string.upper)
				expect(dataStore:Get()).to.equal("ABC")
			end)

			it("should serialize", function()
				local dataStore = DataStore2(UUID(), fakePlayer)
				dataStore:BeforeSave(string.upper)
				dataStore:Set("abc")
				dataStore:Save()
				dataStore:ClearBackup()
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

	describe("combined data stores", test(function(key, player)
		DataStore2.Combine("DATA", key)
		return DataStore2(key, player)
	end, function(key, value)
		local store = DataStore2("DATA", fakePlayer)
		store:ClearBackup()
		local combinedValue = store:Get({})
		combinedValue[key] = value
		-- save("DATA", combinedValue)
	end))
end