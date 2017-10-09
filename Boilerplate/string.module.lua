local newString = {}

newString.replace = function(str, pattern, repl)
    return str:gsub(
        pattern:gsub(
            "([.%%^$()%[%]+*-?])",
            "%%%1"
        ),
        repl
    )
end

newString.match_raw = function(str, pattern)
	return str:match(
		pattern:gsub(
            "([.%%^$()%[%]+*-?])",
            "%%%1"
        )
	)
end

return setmetatable(newString, {
	__index = string
})
