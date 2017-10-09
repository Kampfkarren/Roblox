return function(p)
	if p.Parent == nil then return end
	
	for i,v in pairs(game:GetService("Players"):GetPlayers()) do
		if v.Character then
			if p:IsDescendantOf(v.Character) then
				return v.Character
			end
		end
	end
	
	--ok so this might be an npc
	local par = p
	
	repeat
		par = par.Parent
		
		if par:FindFirstChild("Humanoid") then
			return par
		end
	until par:IsA("Model") or par:IsA("Workspace") --workspace is a model but whatever jic they make it not a model idk
end
