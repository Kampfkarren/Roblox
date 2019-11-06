local function symbol(text)
	local symbol = newproxy(true)
	getmetatable(symbol).__tostring = function()
		return text
	end
	return symbol
end

return {
	SaveFailure = {
		BeforeSaveError = symbol("BeforeSaveError"),
		DataStoreFailure = symbol("DataStoreFailure"),
		InvalidData = symbol("InvalidData"),
	}
}
