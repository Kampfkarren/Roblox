local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local function alwaysFalse()
	return false
end

return function(ray, blacklist, ignoreIf, partToCheck)
	blacklist = blacklist or {}
	ignoreIf = ignoreIf or alwaysFalse
	local results

	while true do
		results = { Workspace:FindPartOnRayWithIgnoreList(ray, blacklist) }

		local hit = results[1]

		if not hit then
			break
		else
			if CollectionService:HasTag(hit, "RaycastOverride") then
				if ignoreIf(hit) then
					table.insert(blacklist, hit)
				else
					break
				end
			else
				local canCollideWith = partToCheck and partToCheck:CanCollideWith(hit) or hit.CanCollide

				if canCollideWith and not ignoreIf(hit) then
					break
				else
					table.insert(blacklist, hit)
				end
			end
		end
	end

	return unpack(results)
end
