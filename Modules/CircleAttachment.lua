local RunService = game:GetService("RunService")

return function(attachment, radius, rate, y)
	y = y or 0
	radius = radius or 4
	rate = rate or 5

	local angle = 0

	coroutine.wrap(function()
		while attachment:IsDescendantOf(game) do
			angle = angle + rate
			local rad = math.rad(angle)

			attachment.Position = Vector3.new(radius * math.sin(rad), y, radius * math.cos(rad))

			RunService.Stepped:wait()
		end
	end)()
end
