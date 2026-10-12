-- Random twists, one per round. Each modifier edits the round context and may
-- return a cleanup function that undoes it when the round ends.
--
-- ctx = { startSpeed, speedMult, participants }

local Modifiers = {
	{
		name = "Classic",
		desc = "No twists. Pure skill.",
		weight = 3,
		apply = function() end,
	},
	{
		name = "Low Gravity",
		desc = "Floaty jumps, long falls!",
		weight = 1,
		apply = function()
			local original = workspace.Gravity
			workspace.Gravity = 70
			return function()
				workspace.Gravity = original
			end
		end,
	},
	{
		name = "Turbo Bomb",
		desc = "The bomb starts FAST.",
		weight = 1,
		apply = function(ctx)
			ctx.startSpeed *= 1.7
		end,
	},
	{
		name = "Hyper Ramp",
		desc = "Every parry speeds the bomb up way more.",
		weight = 1,
		apply = function(ctx)
			ctx.speedMult = 1.25
		end,
	},
	{
		name = "Zoomies",
		desc = "Everyone runs super fast.",
		weight = 1,
		apply = function(ctx)
			local humanoids = {}
			for _, player in ctx.participants do
				local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				if humanoid then
					humanoids[humanoid] = humanoid.WalkSpeed
					humanoid.WalkSpeed = 30
				end
			end
			return function()
				for humanoid, walkSpeed in humanoids do
					if humanoid.Parent then
						humanoid.WalkSpeed = walkSpeed
					end
				end
			end
		end,
	},
}

local totalWeight = 0
for _, modifier in Modifiers do
	totalWeight += modifier.weight
end

local function pick()
	local roll = math.random() * totalWeight
	for _, modifier in Modifiers do
		roll -= modifier.weight
		if roll <= 0 then
			return modifier
		end
	end
	return Modifiers[1]
end

return {
	List = Modifiers,
	Pick = pick,
}
