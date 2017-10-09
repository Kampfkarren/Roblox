--micro-optimize
local Stepped = game:GetService("RunService").Stepped
local SteppedWait = Stepped.wait
local v3n = Vector3.new
local IsDescendantOf = script.IsDescendantOf
local game = game
local cos = math.cos
local sin = math.sin
local rad = math.rad

return function(attachment, radius, rate, y)
	y = y or 0
	radius = radius or 4
	rate = rate or 5
	
	local angle = 0
	
	spawn(function()
		--we don't use connect here because while...:wait() is faster than connect...:disconnect
		while IsDescendantOf(attachment, game) do
			angle = angle + rate
			local _angle = rad(angle)
			
			attachment.Position = v3n(radius * sin(_angle), y, radius * cos(_angle))
			
			SteppedWait(Stepped)
		end
	end)
end
