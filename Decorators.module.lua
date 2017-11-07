local Decorators = {}

local deprecatedWarning = "%s is deprecated. %s"

Decorators.DEPRECATED = function(func, funcName, reason)
	warn(deprecatedWarning:format(funcName, reason))
	return func
end

return Decorators
