return {
	-- What saving method you would like to use
	-- Possible options:
	-- OrderedBackups: The berezaa method that ensures prevention of data loss
	-- Standard: Standard data stores. Equivalent to :GetDataStore(key):GetAsync(UserId)
	SavingMethod = "OrderedBackups",
}
