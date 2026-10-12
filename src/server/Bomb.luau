-- The homing bomb. Movement is simulated on the server; the part is anchored
-- and moved every Heartbeat.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local SLOW_COLOR = Color3.fromRGB(255, 170, 40)
local FAST_COLOR = Color3.fromRGB(255, 40, 40)
local MAX_COLOR = Color3.fromRGB(255, 255, 255)

local Bomb = {}
Bomb.__index = Bomb

function Bomb.new(position, speed)
	local part = Instance.new("Part")
	part.Name = "Bomb"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.one * Config.BOMB.SIZE
	part.Material = Enum.Material.Neon
	part.Color = SLOW_COLOR
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.CFrame = CFrame.new(position)

	local top = Instance.new("Attachment")
	top.Position = Vector3.new(0, Config.BOMB.SIZE * 0.4, 0)
	top.Parent = part
	local bottom = Instance.new("Attachment")
	bottom.Position = Vector3.new(0, -Config.BOMB.SIZE * 0.4, 0)
	bottom.Parent = part

	local trail = Instance.new("Trail")
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Lifetime = 0.25
	trail.LightEmission = 1
	trail.FaceCamera = true
	trail.Transparency = NumberSequence.new(0, 1)
	trail.Color = ColorSequence.new(SLOW_COLOR)
	trail.Parent = part

	local light = Instance.new("PointLight")
	light.Range = 14
	light.Brightness = 3
	light.Color = SLOW_COLOR
	light.Parent = part

	part.Parent = workspace

	return setmetatable({
		part = part,
		trail = trail,
		light = light,
		position = position,
		dir = Vector3.new(0, 0, 1),
		speed = speed,
		baseSpeed = speed,
		freeUntil = 0,
		pausedUntil = 0,
	}, Bomb)
end

-- Fire the bomb straight along `dir` for `freeDistance` studs before it starts homing.
function Bomb:Launch(dir, freeDistance)
	self.dir = dir
	self.freeUntil = os.clock() + freeDistance / self.speed
end

function Bomb:Pause(seconds)
	self.pausedUntil = os.clock() + seconds
end

function Bomb:IsPaused()
	return os.clock() < self.pausedUntil
end

function Bomb:ResetSpeed()
	self.speed = self.baseSpeed
end

function Bomb:SetSpeed(speed)
	self.speed = math.min(speed, Config.BOMB.MAX_SPEED)
end

-- Moves the bomb toward targetPosition. Returns true when it reaches the target.
function Bomb:Step(dt, targetPosition)
	local toTarget = targetPosition - self.position
	local distance = toTarget.Magnitude
	local stepLength = self.speed * dt

	if os.clock() >= self.freeUntil then
		if distance <= Config.BOMB.HIT_RADIUS or distance <= stepLength then
			self.position = targetPosition
			self:_render()
			return true
		end

		local desired = toTarget.Unit
		if distance < self.speed * Config.BOMB.SNAP_TIME then
			self.dir = desired
		else
			local turned = self.dir:Lerp(desired, math.min(1, Config.BOMB.TURN_RATE * dt))
			self.dir = if turned.Magnitude > 1e-3 then turned.Unit else desired
		end
	end

	local nextPosition = self.position + self.dir * stepLength
	local minY = Config.ARENA_CENTER.Y + Config.BOMB.SIZE / 2
	if nextPosition.Y < minY then
		nextPosition = Vector3.new(nextPosition.X, minY, nextPosition.Z)
	end
	self.position = nextPosition
	self:_render()
	return false
end

function Bomb:_render()
	self.part.CFrame = CFrame.new(self.position)

	-- Orange when slow, red when fast, white-hot near max speed
	local t = math.clamp((self.speed - self.baseSpeed) / (Config.BOMB.MAX_SPEED - self.baseSpeed), 0, 1)
	local color = if t < 0.5 then SLOW_COLOR:Lerp(FAST_COLOR, t * 2) else FAST_COLOR:Lerp(MAX_COLOR, (t - 0.5) * 2)
	if color ~= self.part.Color then
		self.part.Color = color
		self.light.Color = color
		self.trail.Color = ColorSequence.new(color)
	end
end

function Bomb:Destroy()
	self.part:Destroy()
end

return Bomb
