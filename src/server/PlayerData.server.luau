--!strict
-- ServerScriptService/Server/PlayerData.server.luau
-- Saves and loads player Coins, Wins, BestSurvival, Perks, and Cosmetics in DataStoreService (gracefully falls back in unpublished Studio places).

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local DATASTORE_NAME = "PropHuntPlayerData_v2"
local playerStore: DataStore? = nil

-- Safely acquire DataStore (avoids errors if Studio API access is disabled)
local ok, result = pcall(function()
	return DataStoreService:GetDataStore(DATASTORE_NAME)
end)
if ok then
	playerStore = result
end

local function loadPlayerData(player: Player)
	if not playerStore then
		return
	end

	local key = "Player_" .. tostring(player.UserId)
	local success, savedData = pcall(function()
		return playerStore:GetAsync(key)
	end)

	if success and typeof(savedData) == "table" then
		local leaderstats = player:WaitForChild("leaderstats", 10)
		if leaderstats then
			local coins = leaderstats:WaitForChild("Coins", 5) :: IntValue?
			if coins and typeof(savedData.Coins) == "number" then
				coins.Value = savedData.Coins
			end
			local wins = leaderstats:WaitForChild("Wins", 5) :: IntValue?
			if wins and typeof(savedData.Wins) == "number" then
				wins.Value = savedData.Wins
			end
			local bestSurvival = leaderstats:WaitForChild("BestSurvival", 5) :: IntValue?
			if bestSurvival and typeof(savedData.BestSurvival) == "number" then
				bestSurvival.Value = savedData.BestSurvival
			end
		end

		if savedData.HasSpeedPerk == true then
			player:SetAttribute("HasSpeedPerk", true)
		end
		if savedData.HasHealthPerk == true then
			player:SetAttribute("HasHealthPerk", true)
		end
		if typeof(savedData.OwnedSkins) == "string" then
			player:SetAttribute("OwnedSkins", savedData.OwnedSkins)
		end
		if typeof(savedData.EquippedSkin) == "string" then
			player:SetAttribute("EquippedSkin", savedData.EquippedSkin)
		end
		if typeof(savedData.TauntSoundPack) == "string" then
			player:SetAttribute("TauntSoundPack", savedData.TauntSoundPack)
		end
	end
end

local function savePlayerData(player: Player)
	if not playerStore then
		return
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return
	end

	local coins = leaderstats:FindFirstChild("Coins") :: IntValue?
	local wins = leaderstats:FindFirstChild("Wins") :: IntValue?
	local bestSurvival = leaderstats:FindFirstChild("BestSurvival") :: IntValue?

	local key = "Player_" .. tostring(player.UserId)
	local dataToSave = {
		Coins = if coins then coins.Value else 0,
		Wins = if wins then wins.Value else 0,
		BestSurvival = if bestSurvival then bestSurvival.Value else 0,
		HasSpeedPerk = player:GetAttribute("HasSpeedPerk") == true,
		HasHealthPerk = player:GetAttribute("HasHealthPerk") == true,
		OwnedSkins = tostring(player:GetAttribute("OwnedSkins") or "Default"),
		EquippedSkin = tostring(player:GetAttribute("EquippedSkin") or "Default"),
		TauntSoundPack = tostring(player:GetAttribute("TauntSoundPack") or "Classic"),
	}

	for attempt = 1, 2 do
		local okSave = pcall(function()
			playerStore:UpdateAsync(key, function(_oldValue)
				return dataToSave
			end)
		end)
		if okSave then
			break
		end
		task.wait(0.5 * attempt)
	end
end

Players.PlayerAdded:Connect(loadPlayerData)
for _, player in Players:GetPlayers() do
	task.spawn(loadPlayerData, player)
end

Players.PlayerRemoving:Connect(savePlayerData)

game:BindToClose(function()
	if RunService:IsStudio() then
		return
	end
	for _, player in Players:GetPlayers() do
		task.spawn(savePlayerData, player)
	end
	task.wait(2)
end)

