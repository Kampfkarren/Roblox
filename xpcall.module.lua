return function(call, handler)
	local succ, err = pcall(call)
	
	if not succ then
		handler(err)
	end
end
