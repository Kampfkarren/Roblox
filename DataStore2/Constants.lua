local function createSymbol(name)
	local symbol = newproxy(true)

	getmetatable(symbol).__tostring = function()
		return name
	end

	return symbol
end

return {
	SaveSuccess = createSymbol("SaveSuccess"),
	SaveSuccessNil = createSymbol("SaveSuccessNil"),

	SaveFailNotUpdated = createSymbol("SaveFailNotUpdated"),
	SaveFailInvalidData = createSymbol("SaveFailInvalidData"),
	SaveFailStudio = createSymbol("SaveFailStudio"),
	SaveFailBackup = createSymbol("SaveFailBackup"),
	SaveFailBeforeSave = createSymbol("SaveFailBeforeSave"),
	SaveFailAfterSave = createSymbol("SaveFailAfterSave"),
}
