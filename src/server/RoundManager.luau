-- The game loop: lobby -> intermission -> round (bomb + parries) -> winner -> repeat.
--
-- Round state is published as attributes on ReplicatedStorage so clients that
-- join mid-round can read it: Phase, Message, EndsAt, Modifier, ModifierDesc,
-- TargetUserId, BombSpeed.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Arena = require(script.Parent.Arena)
local Bomb = require(script.Parent.Bomb)
local Data = require(script.Parent.Data)
local Modifiers = require(script.Parent.Modifiers)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ParryRemote = Remotes:WaitForChild("Parry")
local FxRemote = Remotes:WaitForChild("Fx")

local RoundManager = {}

local alive = {} -- [Player] = true while still in the round
local lastParry = {} -- [Player] = os.clock() of their last accepted parry press
local lastAim = {} -- [Player] = Vector3 aim direction sent with that press
local parryCounts = {} -- [Player] = successful parries this round
local roundActive = false
local roundCtx = nil
local bomb = nil
local target = nil
local targetHighlight = nil

local function setState(phase, message, duration)
	ReplicatedStorage:SetAttribute("Phase", phase)
	ReplicatedStorage:SetAttribute("Message", message)
	ReplicatedStorage:SetAttribute("EndsAt", if duration then workspace:GetServerTimeNow() + duration else 0)
end

-- Returns the HumanoidRootPart and Humanoid of a living character, or nil.
local function getRoot(player)
	local character = player and player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 then
		return nil
	end
	return root, humanoid
end

local function countAlive()
	local count = 0
	for _ in alive do
		count += 1
	end
	return count
end

local function minPlayers()
	if Config.STUDIO_SOLO and RunService:IsStudio() then
		return 1
	end
	return Config.MIN_PLAYERS
end

local function setTarget(player)
	target = player
	if targetHighlight then
		targetHighlight:Destroy()
		targetHighlight = nil
	end
	if player and player.Character then
		local highlight = Instance.new("Highlight")
		highlight.FillColor = Color3.fromRGB(255, 60, 60)
		highlight.OutlineColor = Color3.new(1, 1, 1)
		highlight.FillTransparency = 0.5
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		highlight.Parent = player.Character
		targetHighlight = highlight
	end
	ReplicatedStorage:SetAttribute("TargetUserId", if player then player.UserId else 0)
end

-- With an aim direction, picks the living player closest to where the parrier
-- is looking. Without one, picks at random. Falls back to `exclude` when they
-- are the only one left (solo practice).
local function pickTarget(exclude, aimDir, fromPosition)
	local best, bestScore = nil, -math.huge
	for player in alive do
		if player ~= exclude then
			local root = getRoot(player)
			if root then
				local score
				if aimDir then
					local offset = root.Position - fromPosition
					score = if offset.Magnitude > 0.01 then aimDir:Dot(offset.Unit) else 1
				else
					score = math.random()
				end
				if score > bestScore then
					best, bestScore = player, score
				end
			end
		end
	end
	if not best and exclude and alive[exclude] then
		return exclude
	end
	return best
end

local function eliminate(player, pushDir)
	if not alive[player] then
		return
	end
	alive[player] = nil

	local root, humanoid = getRoot(player)
	if root and pushDir then
		local flat = Vector3.new(pushDir.X, 0, pushDir.Z)
		flat = if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(0, 0, 1)
		local velocity = flat * Config.KNOCKBACK.HORIZONTAL + Vector3.yAxis * Config.KNOCKBACK.VERTICAL

		-- The client owns its character's physics, so it applies the fling itself
		FxRemote:FireClient(player, "Launch", velocity)
		FxRemote:FireAllClients("Explode", root.Position)

		local explosion = Instance.new("Explosion")
		explosion.Position = root.Position
		explosion.BlastPressure = 0
		explosion.BlastRadius = 0
		explosion.DestroyJointRadiusPercent = 0
		explosion.ExplosionType = Enum.ExplosionType.NoCraters
		explosion.Parent = workspace

		task.delay(Config.KNOCKBACK.KILL_DELAY, function()
			if humanoid.Parent then
				humanoid.Health = 0
			end
		end)
	elseif humanoid then
		humanoid.Health = 0
	end

	FxRemote:FireAllClients("Eliminated", player.DisplayName, countAlive())
end

local function sanitizeAim(player, aim)
	local root = getRoot(player)
	local fallback = if root then root.CFrame.LookVector else Vector3.new(0, 0, 1)
	if typeof(aim) ~= "Vector3" or aim.Magnitude < 0.01 or aim.Magnitude ~= aim.Magnitude then
		return fallback
	end
	-- Keep the launch mostly horizontal so the bomb doesn't fly into the sky or floor
	local unit = aim.Unit
	local flattened = Vector3.new(unit.X, math.clamp(unit.Y, -0.2, 0.4), unit.Z)
	return if flattened.Magnitude > 0.01 then flattened.Unit else fallback
end

local function parryRange()
	return Config.PARRY.BASE_RANGE + bomb.speed * Config.PARRY.RANGE_PER_SPEED
end

local function doParry(player)
	local root = getRoot(player)
	if not root then
		return
	end
	local aim = lastAim[player] or root.CFrame.LookVector
	lastParry[player] = nil -- a successful parry resets your cooldown
	parryCounts[player] = (parryCounts[player] or 0) + 1

	bomb:SetSpeed(bomb.speed * roundCtx.speedMult + Config.BOMB.SPEED_ADD)
	local newTarget = pickTarget(player, aim, root.Position)
	local solo = newTarget == player
	bomb:Launch(aim, if solo then Config.BOMB.SOLO_FREE_DISTANCE else Config.BOMB.FREE_DISTANCE)
	setTarget(newTarget)
	FxRemote:FireAllClients("Parry", bomb.position, player.UserId)
end

ParryRemote.OnServerEvent:Connect(function(player, aim)
	if not roundActive or not alive[player] or not bomb then
		return
	end
	local now = os.clock()
	local last = lastParry[player]
	-- Slightly looser than the client's cooldown to absorb network jitter
	if last and now - last < Config.PARRY.COOLDOWN * 0.85 then
		return
	end
	lastParry[player] = now
	lastAim[player] = sanitizeAim(player, aim)

	if player == target and not bomb:IsPaused() then
		local root = getRoot(player)
		if root and (bomb.position - root.Position).Magnitude <= parryRange() then
			doParry(player)
		end
	end
end)

local function teleportToLobby(player)
	local character = player.Character
	if character then
		character:PivotTo(Arena.GetLobbyCFrame())
	end
end

local function runRound()
	local participants = {}
	for _, player in Players:GetPlayers() do
		if getRoot(player) then
			table.insert(participants, player)
		end
	end
	if #participants < minPlayers() then
		return
	end

	local ctx = {
		startSpeed = Config.BOMB.START_SPEED,
		speedMult = Config.BOMB.SPEED_MULT,
		participants = participants,
	}
	local modifier = Modifiers.Pick()
	local cleanupModifier = modifier.apply(ctx)
	roundCtx = ctx
	ReplicatedStorage:SetAttribute("Modifier", modifier.name)
	ReplicatedStorage:SetAttribute("ModifierDesc", modifier.desc)

	table.clear(alive)
	table.clear(lastParry)
	table.clear(lastAim)
	table.clear(parryCounts)

	local connections = {}
	for i, player in participants do
		local root, humanoid = getRoot(player)
		alive[player] = true
		parryCounts[player] = 0
		root.Parent:PivotTo(Arena.GetRingCFrame(i, #participants))
		table.insert(
			connections,
			humanoid.Died:Connect(function()
				eliminate(player)
			end)
		)
	end

	local solo = #participants == 1
	local endWhenAliveAtOrBelow = if solo then 0 else 1
	roundActive = true

	setState("Countdown", modifier.name, Config.PRE_ROUND)
	task.wait(Config.PRE_ROUND)

	bomb = Bomb.new(Arena.GetBombSpawn(), ctx.startSpeed)
	bomb:Pause(0.5)
	setState("Playing", if solo then "Practice!" else "Survive!")

	local startedAt = os.clock()
	local inOvertime = false

	while countAlive() > endWhenAliveAtOrBelow do
		local dt = RunService.Heartbeat:Wait()

		for player in alive do
			local root = getRoot(player)
			if not root or Arena.IsBelowArena(root.Position) then
				eliminate(player)
			end
		end
		if countAlive() <= endWhenAliveAtOrBelow then
			break
		end

		if not inOvertime and os.clock() - startedAt > Config.OVERTIME_AFTER then
			inOvertime = true
			setState("Playing", "OVERTIME!")
		end
		if inOvertime then
			bomb:SetSpeed(bomb.speed + Config.BOMB.OVERTIME_ACCEL * dt)
		end

		if not bomb:IsPaused() then
			if not target or not alive[target] or not getRoot(target) then
				setTarget(pickTarget(nil))
			end
			local targetRoot = getRoot(target)
			if targetRoot and bomb:Step(dt, targetRoot.Position) then
				local pressed = lastParry[target]
				if pressed and os.clock() - pressed <= Config.PARRY.WINDOW then
					doParry(target)
				else
					local victim = target
					setTarget(nil)
					eliminate(victim, bomb.dir)
					bomb:ResetSpeed()
					bomb:Pause(Config.BOMB.PAUSE_AFTER_HIT)
				end
			end
		end

		ReplicatedStorage:SetAttribute("BombSpeed", math.floor(bomb.speed))
	end

	-- Round over
	roundActive = false
	for _, connection in connections do
		connection:Disconnect()
	end
	if cleanupModifier then
		cleanupModifier()
	end
	setTarget(nil)
	bomb:Destroy()
	bomb = nil

	local winner = if solo then nil else next(alive)
	for _, player in participants do
		if player.Parent then
			local reward = Config.REWARDS.PARTICIPATE + parryCounts[player] * Config.REWARDS.PARRY
			if player == winner then
				reward += Config.REWARDS.WIN
				Data.AddWin(player)
			end
			Data.AddCoins(player, reward)
			FxRemote:FireClient(player, "Reward", reward, parryCounts[player])
		end
	end

	if winner then
		setState("Ended", winner.DisplayName .. " wins!", Config.POST_ROUND)
	elseif solo then
		setState("Ended", ("Practice over: %d parries!"):format(parryCounts[participants[1]]), Config.POST_ROUND)
	else
		setState("Ended", "Nobody survived!", Config.POST_ROUND)
	end
	ReplicatedStorage:SetAttribute("Modifier", "")
	ReplicatedStorage:SetAttribute("ModifierDesc", "")
	ReplicatedStorage:SetAttribute("BombSpeed", 0)

	task.wait(Config.POST_ROUND)
	for player in alive do
		if player.Parent then
			teleportToLobby(player)
		end
	end
	table.clear(alive)
end

function RoundManager.Start()
	Players.RespawnTime = Config.RESPAWN_TIME

	-- Always (re)spawn in the lobby, whatever other SpawnLocations the place has
	local function onCharacterAdded(player, character)
		character:WaitForChild("HumanoidRootPart")
		task.wait()
		if not alive[player] and character.Parent then
			character:PivotTo(Arena.GetLobbyCFrame())
		end
	end
	local function onPlayerAdded(player)
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
		if player.Character then
			task.spawn(onCharacterAdded, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		alive[player] = nil
		lastParry[player] = nil
		lastAim[player] = nil
	end)

	task.spawn(function()
		while true do
			local playerCount = #Players:GetPlayers()
			local needed = minPlayers()
			if playerCount < needed then
				setState("Waiting", ("Waiting for players (%d/%d)"):format(playerCount, needed))
				task.wait(1)
				continue
			end

			setState("Intermission", "Next round starting", Config.INTERMISSION)
			task.wait(Config.INTERMISSION)
			runRound()
		end
	end)
end

return RoundManager
