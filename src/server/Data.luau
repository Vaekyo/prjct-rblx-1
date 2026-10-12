-- Coins + Wins leaderstats, saved with DataStoreService.
-- In Studio, saving only works with Game Settings > Security >
-- "Enable Studio Access to API Services" turned on; otherwise stats just reset.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Data = {}

local store = nil -- nil = not tried yet, false = unavailable
local loaded = {} -- [Player] = true once their save loaded, so a failed load never overwrites real data

local function getStore()
	if store == nil then
		local ok, result = pcall(DataStoreService.GetDataStore, DataStoreService, Config.DATASTORE_NAME)
		store = ok and result or false
		if not ok then
			warn("[Data] DataStore unavailable, progress will not save:", result)
		end
	end
	return store or nil
end

local function keyFor(player)
	return "player_" .. player.UserId
end

local function onPlayerAdded(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Parent = leaderstats
	local wins = Instance.new("IntValue")
	wins.Name = "Wins"
	wins.Parent = leaderstats
	leaderstats.Parent = player

	local dataStore = getStore()
	if not dataStore then
		return
	end
	local ok, saved = pcall(dataStore.GetAsync, dataStore, keyFor(player))
	if not ok then
		warn("[Data] Load failed for", player.Name, saved)
		return
	end
	if not player.Parent then
		return
	end
	if type(saved) == "table" then
		coins.Value = saved.coins or 0
		wins.Value = saved.wins or 0
	end
	loaded[player] = true
end

local function save(player)
	local dataStore = getStore()
	local leaderstats = player:FindFirstChild("leaderstats")
	if not dataStore or not loaded[player] or not leaderstats then
		return
	end
	local payload = { coins = leaderstats.Coins.Value, wins = leaderstats.Wins.Value }
	local ok, err = pcall(dataStore.SetAsync, dataStore, keyFor(player), payload)
	if not ok then
		warn("[Data] Save failed for", player.Name, err)
	end
end

function Data.Init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		save(player)
		loaded[player] = nil
	end)

	game:BindToClose(function()
		local pending = 0
		for _, player in Players:GetPlayers() do
			pending += 1
			task.spawn(function()
				save(player)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 20
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(Config.AUTOSAVE_INTERVAL)
			for _, player in Players:GetPlayers() do
				task.spawn(save, player)
			end
		end
	end)
end

local function getStat(player, name)
	local leaderstats = player:FindFirstChild("leaderstats")
	return leaderstats and leaderstats:FindFirstChild(name)
end

function Data.AddCoins(player, amount)
	local coins = getStat(player, "Coins")
	if coins then
		coins.Value += amount
	end
end

function Data.AddWin(player)
	local wins = getStat(player, "Wins")
	if wins then
		wins.Value += 1
	end
end

return Data
