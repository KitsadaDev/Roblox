--!strict
-- ServerScriptService/Server/PlayerData.server.luau
-- Saves and loads player Coins in DataStoreService (gracefully falls back in unpublished Studio places).

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local DATASTORE_NAME = "PropHuntPlayerData_v1"
local playerStore: DataStore? = nil

-- Safely acquire DataStore (avoids errors if Studio API access is disabled)
local ok, result = pcall(function()
	return DataStoreService:GetDataStore(DATASTORE_NAME)
end)
if ok then
	playerStore = result
end

local function loadPlayerCoins(player: Player)
	if not playerStore then
		return
	end

	local key = "Player_" .. tostring(player.UserId)
	local success, savedData = pcall(function()
		return playerStore:GetAsync(key)
	end)

	if success and typeof(savedData) == "table" and typeof(savedData.Coins) == "number" then
		local leaderstats = player:WaitForChild("leaderstats", 10)
		local coins = leaderstats and leaderstats:WaitForChild("Coins", 5) :: IntValue?
		if coins then
			coins.Value = savedData.Coins
		end
	end
end

local function savePlayerCoins(player: Player)
	if not playerStore then
		return
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("Coins") :: IntValue?
	if not coins then
		return
	end

	local key = "Player_" .. tostring(player.UserId)
	local coinsToSave = coins.Value

	pcall(function()
		playerStore:SetAsync(key, {
			Coins = coinsToSave,
		})
	end)
end

Players.PlayerAdded:Connect(loadPlayerCoins)
for _, player in Players:GetPlayers() do
	task.spawn(loadPlayerCoins, player)
end

Players.PlayerRemoving:Connect(savePlayerCoins)

game:BindToClose(function()
	if RunService:IsStudio() then
		return
	end
	for _, player in Players:GetPlayers() do
		task.spawn(savePlayerCoins, player)
	end
	task.wait(2)
end)

