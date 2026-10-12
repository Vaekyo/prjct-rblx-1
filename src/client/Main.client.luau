-- Client: parry input, HUD, and game-feel effects (rings, screen shake, ragdoll fling).

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ParryRemote = Remotes:WaitForChild("Parry")
local FxRemote = Remotes:WaitForChild("Fx")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

--------------------------------------------------------------------------------
-- HUD
--------------------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "BombBonkHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local function makeLabel(props)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.TextScaled = true
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Text = ""
	for key, value in props do
		label[key] = value
	end
	label.Parent = gui
	return label
end

local vignette = Instance.new("Frame")
vignette.Size = UDim2.fromScale(1, 1)
vignette.BackgroundColor3 = Color3.fromRGB(255, 30, 30)
vignette.BackgroundTransparency = 1
vignette.BorderSizePixel = 0
vignette.ZIndex = 0
vignette.Parent = gui

local title = makeLabel({ Position = UDim2.new(0.5, 0, 0, 50), Size = UDim2.new(0.7, 0, 0, 46) })
local subtitle = makeLabel({
	Position = UDim2.new(0.5, 0, 0, 98),
	Size = UDim2.new(0.6, 0, 0, 26),
	Font = Enum.Font.GothamBold,
	TextColor3 = Color3.fromRGB(255, 220, 120),
})
local targetedLabel = makeLabel({
	Position = UDim2.fromScale(0.5, 0.68),
	Size = UDim2.new(0.6, 0, 0, 40),
	TextColor3 = Color3.fromRGB(255, 80, 80),
	Text = "YOU'RE TARGETED! CLICK / F TO PARRY",
	Visible = false,
})
local speedLabel = makeLabel({
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -20, 1, -20),
	Size = UDim2.new(0, 220, 0, 28),
	TextXAlignment = Enum.TextXAlignment.Right,
	Font = Enum.Font.GothamBold,
})
local toast = makeLabel({
	Position = UDim2.new(0.5, 0, 1, -110),
	Size = UDim2.new(0.4, 0, 0, 34),
	TextColor3 = Color3.fromRGB(255, 215, 60),
	TextTransparency = 1,
	TextStrokeTransparency = 1,
})
local feed = makeLabel({
	AnchorPoint = Vector2.new(0, 0),
	Position = UDim2.new(0, 20, 0, 140),
	Size = UDim2.new(0, 320, 0, 110),
	TextScaled = false,
	TextSize = 18,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
})

-- Parry cooldown bar
local barBack = Instance.new("Frame")
barBack.AnchorPoint = Vector2.new(0.5, 1)
barBack.Position = UDim2.new(0.5, 0, 1, -60)
barBack.Size = UDim2.new(0, 220, 0, 12)
barBack.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
barBack.BackgroundTransparency = 0.3
barBack.BorderSizePixel = 0
barBack.Parent = gui
Instance.new("UICorner", barBack).CornerRadius = UDim.new(1, 0)
local barFill = Instance.new("Frame")
barFill.Size = UDim2.fromScale(1, 1)
barFill.BackgroundColor3 = Color3.fromRGB(80, 200, 255)
barFill.BorderSizePixel = 0
barFill.Parent = barBack
Instance.new("UICorner", barFill).CornerRadius = UDim.new(1, 0)

local feedLines = {}
local function pushFeed(text)
	table.insert(feedLines, 1, text)
	if #feedLines > 4 then
		table.remove(feedLines)
	end
	feed.Text = table.concat(feedLines, "\n")
end

local function showToast(text)
	toast.Text = text
	toast.TextTransparency = 0
	toast.TextStrokeTransparency = 0.4
	toast.Position = UDim2.new(0.5, 0, 1, -110)
	local info = TweenInfo.new(2.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	TweenService:Create(toast, info, {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		Position = UDim2.new(0.5, 0, 1, -150),
	}):Play()
end

--------------------------------------------------------------------------------
-- Effects
--------------------------------------------------------------------------------

local shakeAmount = 0
RunService:BindToRenderStep("BombBonkShake", Enum.RenderPriority.Camera.Value + 1, function(dt)
	if shakeAmount > 0.01 then
		local r = shakeAmount
		camera.CFrame *= CFrame.Angles(
			math.rad((math.random() - 0.5) * r),
			math.rad((math.random() - 0.5) * r),
			math.rad((math.random() - 0.5) * r)
		)
		shakeAmount *= math.exp(-dt * 8)
	end
end)

local function shake(amount)
	shakeAmount = math.max(shakeAmount, amount)
end

local function spawnRing(position, color, size, duration)
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Ball
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Material = Enum.Material.ForceField
	ring.Color = color
	ring.Size = Vector3.one
	ring.CFrame = CFrame.new(position)
	ring.Parent = workspace
	local tween = TweenService:Create(ring, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.one * size,
		Transparency = 1,
	})
	tween.Completed:Connect(function()
		ring:Destroy()
	end)
	tween:Play()
end

local function getRoot()
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

--------------------------------------------------------------------------------
-- Parry input (mouse, F, gamepad R2, and an on-screen button on mobile)
--------------------------------------------------------------------------------

local lastPress = -math.huge

local function parry()
	local now = os.clock()
	if now - lastPress < Config.PARRY.COOLDOWN then
		return
	end
	lastPress = now
	ParryRemote:FireServer(camera.CFrame.LookVector)

	local root = getRoot()
	if root then
		spawnRing(root.Position, Color3.fromRGB(120, 200, 255), 8, 0.2)
	end
end

ContextActionService:BindAction("BombBonkParry", function(_, state)
	if state == Enum.UserInputState.Begin then
		parry()
	end
	return Enum.ContextActionResult.Pass
end, true, Enum.UserInputType.MouseButton1, Enum.KeyCode.F, Enum.KeyCode.ButtonR2)
ContextActionService:SetTitle("BombBonkParry", "PARRY")

--------------------------------------------------------------------------------
-- Server events
--------------------------------------------------------------------------------

FxRemote.OnClientEvent:Connect(function(kind, ...)
	if kind == "Parry" then
		local position, userId = ...
		spawnRing(position, Color3.fromRGB(80, 220, 255), 16, 0.3)
		if userId == player.UserId then
			lastPress = -math.huge -- successful parry resets the cooldown
			shake(1.5)
		end
	elseif kind == "Launch" then
		local velocity = ...
		local character = player.Character
		local root = getRoot()
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid then
			humanoid.PlatformStand = true
			root.AssemblyLinearVelocity = velocity
			root.AssemblyAngularVelocity = Vector3.new(math.random(-20, 20), math.random(-20, 20), math.random(-20, 20))
		end
		shake(6)
	elseif kind == "Explode" then
		local position = ...
		local root = getRoot()
		local distance = if root then (root.Position - position).Magnitude else math.huge
		shake(math.clamp(4 - distance / 20, 0, 4))
	elseif kind == "Eliminated" then
		local name, remaining = ...
		pushFeed(("%s got BONKED! (%d left)"):format(name, remaining))
	elseif kind == "Reward" then
		local coins, parries = ...
		showToast(("+%d coins  (%d parries)"):format(coins, parries))
	end
end)

--------------------------------------------------------------------------------
-- HUD update
--------------------------------------------------------------------------------

RunService.RenderStepped:Connect(function()
	local phase = ReplicatedStorage:GetAttribute("Phase") or "Waiting"
	local endsAt = ReplicatedStorage:GetAttribute("EndsAt") or 0
	local remaining = if endsAt > 0 then math.max(0, math.ceil(endsAt - workspace:GetServerTimeNow())) else nil

	title.Text = ReplicatedStorage:GetAttribute("Message") or ""
	if phase == "Intermission" and remaining then
		subtitle.Text = ("Starting in %d"):format(remaining)
	elseif phase == "Countdown" and remaining then
		subtitle.Text = ("%s  -  %d"):format(ReplicatedStorage:GetAttribute("ModifierDesc") or "", remaining)
	elseif phase == "Playing" then
		subtitle.Text = ReplicatedStorage:GetAttribute("ModifierDesc") or ""
	else
		subtitle.Text = ""
	end

	local playing = phase == "Playing"
	local targeted = playing and ReplicatedStorage:GetAttribute("TargetUserId") == player.UserId
	targetedLabel.Visible = targeted
	vignette.BackgroundTransparency = if targeted then 0.8 + 0.08 * math.sin(os.clock() * 14) else 1

	local speed = ReplicatedStorage:GetAttribute("BombSpeed") or 0
	speedLabel.Text = if playing and speed > 0 then ("Bomb speed: %d"):format(speed) else ""

	local charge = math.clamp((os.clock() - lastPress) / Config.PARRY.COOLDOWN, 0, 1)
	barFill.Size = UDim2.fromScale(charge, 1)
	barFill.BackgroundColor3 = if charge >= 1 then Color3.fromRGB(80, 200, 255) else Color3.fromRGB(120, 120, 140)
end)
