local RunService = game:GetService("RunService")

return function(num)
	num = num or 0.0001

	local timeStarted = tick()

	--always guarantee at least one yield
	while true do
		RunService.Stepped:Wait()

		local difference = tick() - timeStarted

		if difference >= num then
			return difference
		end
	end
end
