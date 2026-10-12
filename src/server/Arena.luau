-- Builds a simple arena + lobby so the game runs in an empty place.
-- To use your own map, put a Model named "BombBonkMap" in Workspace and
-- line it up with ARENA_CENTER / LOBBY_CENTER in Config.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Arena = {}

local CENTER = Config.ARENA_CENTER
local RADIUS = Config.ARENA_RADIUS
local LOBBY = Config.LOBBY_CENTER

local function makePart(parent, props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		part[key] = value
	end
	part.Parent = parent
	return part
end

function Arena.Build()
	if workspace:FindFirstChild("BombBonkMap") then
		return
	end

	local map = Instance.new("Model")
	map.Name = "BombBonkMap"

	-- Arena floor: a flat disc whose top surface sits at CENTER.Y
	local discRotation = CFrame.Angles(0, 0, math.rad(90))
	makePart(map, {
		Name = "ArenaFloor",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(4, RADIUS * 2, RADIUS * 2),
		CFrame = CFrame.new(CENTER - Vector3.new(0, 2, 0)) * discRotation,
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(45, 48, 66),
	})
	makePart(map, {
		Name = "CenterMark",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, 18, 18),
		CFrame = CFrame.new(CENTER + Vector3.new(0, 0.05, 0)) * discRotation,
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 90, 60),
		CanCollide = false,
	})

	-- Glowing posts around the edge so players can see where the drop is
	local postCount = 24
	for i = 1, postCount do
		local angle = (i / postCount) * math.pi * 2
		local position = CENTER + Vector3.new(math.cos(angle) * (RADIUS - 1), 1.5, math.sin(angle) * (RADIUS - 1))
		makePart(map, {
			Name = "EdgePost",
			Size = Vector3.new(1, 3, 1),
			CFrame = CFrame.new(position),
			Material = Enum.Material.Neon,
			Color = i % 2 == 0 and Color3.fromRGB(255, 200, 60) or Color3.fromRGB(80, 200, 255),
			CanCollide = false,
		})
	end

	-- Lobby
	local half = Config.LOBBY_SIZE / 2
	makePart(map, {
		Name = "LobbyFloor",
		Size = Vector3.new(Config.LOBBY_SIZE, 4, Config.LOBBY_SIZE),
		CFrame = CFrame.new(LOBBY - Vector3.new(0, 2, 0)),
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(70, 74, 100),
	})
	for _, side in { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) } do
		local alongX = side.Z ~= 0
		makePart(map, {
			Name = "LobbyWall",
			Size = alongX and Vector3.new(Config.LOBBY_SIZE, 6, 1) or Vector3.new(1, 6, Config.LOBBY_SIZE),
			CFrame = CFrame.new(LOBBY + side * half + Vector3.new(0, 3, 0)),
			Material = Enum.Material.ForceField,
			Color = Color3.fromRGB(80, 200, 255),
			Transparency = 0.5,
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.new(LOBBY + Vector3.new(0, 0.5, 0))
	spawn.Material = Enum.Material.Neon
	spawn.Color = Color3.fromRGB(80, 200, 255)
	spawn.Parent = map

	map.Parent = workspace
end

-- Where participant i (of n) stands at the start of a round, facing the middle.
function Arena.GetRingCFrame(i, n)
	local angle = (i / n) * math.pi * 2
	local distance = RADIUS * 0.6
	local position = CENTER + Vector3.new(math.cos(angle) * distance, 3, math.sin(angle) * distance)
	return CFrame.lookAt(position, Vector3.new(CENTER.X, position.Y, CENTER.Z))
end

function Arena.GetBombSpawn()
	return CENTER + Vector3.new(0, 8, 0)
end

function Arena.GetLobbyCFrame()
	local spread = math.floor(Config.LOBBY_SIZE * 0.3)
	local offset = Vector3.new(math.random(-spread, spread), 4, math.random(-spread, spread))
	return CFrame.new(LOBBY + offset)
end

function Arena.IsBelowArena(position)
	return position.Y < CENTER.Y - Config.FALL_LIMIT
end

return Arena
