return function()
	local DataStoreService = game:GetService("DataStoreService")

	local DataStore2 = require(script:FindFirstAncestor("Root").Modules.DataStore2)

	local fakePlayer = {}
	fakePlayer.UserId = 156

	local function save(key, value)
		local dataKey = key .. "/" .. fakePlayer.UserId
		local dataStore = DataStoreService:GetDataStore(dataKey)
		local orderedDataStore = DataStoreService:GetOrderedDataStore(dataKey)

		local timeKey = os.time()
		dataStore:SetAsync(timeKey, value)
		orderedDataStore:SetAsync(timeKey, timeKey)
	end

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
end