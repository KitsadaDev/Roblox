--!strict
-- ServerScriptService/Server/RoundManager.server.luau
-- Complete Round Management System: Teams Setup, Leaderstats (Coins), Game Loop States, Win Conditions, and Cleanup.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")
local RunService = game:GetService("RunService")

local PropRemotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PropRemotes"))
local voteMapEvent = PropRemotes.VoteMapRequest
local startGameEvent = PropRemotes.StartGameRequest
local roundEventNotice = PropRemotes.RoundEventNotice

local mapBuilderModule = script.Parent:FindFirstChild("MapBuilder") or script:FindFirstChild("MapBuilder")
local MapBuilder = require(mapBuilderModule :: ModuleScript)

--------------------------------------------------------------------------------
-- TEST MODE
-- true  = Shorter phase timers. When playing alone in Studio, the round starts
--         with just 1 player, who is put on the Hiders team automatically.
-- false = Normal settings for a published game (set this before publishing!)
-- Test mode only applies inside Roblox Studio; real servers always use normal settings.
--------------------------------------------------------------------------------
local TEST_MODE = true
local IS_TEST = TEST_MODE and RunService:IsStudio()

-- Round Timing Constants (in seconds)
local MIN_PLAYERS = if IS_TEST then 1 else 2
local INTERMISSION_TIME = 30 -- 30 seconds map voting countdown after pressing Start
local HIDING_PHASE_TIME = if IS_TEST then 10 else 60
local SURVIVOR_REVEAL_TIME = 15 -- 15 seconds blinking survivor reveal before returning to Lobby
local NO_SURVIVOR_POST_TIME = 6
local WIN_REWARD_COINS = 50

local function getHuntingPhaseTime(playerCount: number): number
	if IS_TEST then
		return 60
	end
	if playerCount <= 8 then
		return 180 -- 3 minutes (2-8 players)
	elseif playerCount <= 20 then
		return 210 -- 3.5 minutes (9-20 players)
	elseif playerCount <= 35 then
		return 240 -- 4 minutes (21-35 players)
	else
		return 300 -- 5 minutes (36+ players)
	end
end

if IS_TEST then
	warn("[RoundManager] TEST MODE is ON (Studio only): short timers, solo play allowed. Set TEST_MODE = false before publishing.")
end

--------------------------------------------------------------------------------
-- 1. TEAMS SETUP
--------------------------------------------------------------------------------
local function getOrCreateTeam(name: string, color: BrickColor, autoAssignable: boolean): Team
	local existing = Teams:FindFirstChild(name)
	if existing and existing:IsA("Team") then
		return existing
	end

	local team = Instance.new("Team")
	team.Name = name
	team.TeamColor = color
	team.AutoAssignable = autoAssignable
	team.Parent = Teams
	return team
end

local lobbyTeam = getOrCreateTeam("Lobby", BrickColor.new("Medium stone grey"), true)
local hidersTeam = getOrCreateTeam("Hiders", BrickColor.new("Bright blue"), false)
local seekersTeam = getOrCreateTeam("Seekers", BrickColor.new("Bright red"), false)

--------------------------------------------------------------------------------
-- 2. LEADERSTATS & PLAYER TRACKING
--------------------------------------------------------------------------------
-- Track active round participants so rewards and win checks remain accurate
local activeHiders: { [Player]: boolean } = {}
local activeSeekers: { [Player]: boolean } = {}
local hiderRoundStartTimes: { [Player]: number } = {}
local lastManStandingTriggered = false

local function recordHiderSurvivalTime(player: Player)
	local startTime = hiderRoundStartTimes[player]
	if not startTime then
		return
	end
	hiderRoundStartTimes[player] = nil
	local survivedSeconds = math.max(0, math.floor(os.clock() - startTime))
	player:SetAttribute("LastRoundSurvival", survivedSeconds)
	local leaderstats = player:FindFirstChild("leaderstats")
	local bestSurvival = leaderstats and leaderstats:FindFirstChild("BestSurvival") :: IntValue?
	if bestSurvival and survivedSeconds > bestSurvival.Value then
		bestSurvival.Value = survivedSeconds
	end
end

local function checkLastManStanding(isSoloTest: boolean)
	if isSoloTest or lastManStandingTriggered then
		return
	end
	if workspace:GetAttribute("RoundState") ~= "HuntingPhase" then
		return
	end

	local lastHider: Player? = nil
	local aliveCount = 0
	for p in activeHiders do
		if p.Parent == Players and p.Character then
			local hum = p.Character:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 then
				aliveCount += 1
				lastHider = p
			end
		end
	end

	if aliveCount == 1 and lastHider then
		lastManStandingTriggered = true
		roundEventNotice:FireAllClients("LastManStanding", {
			HiderName = lastHider.DisplayName,
		})
	end
end

--------------------------------------------------------------------------------
-- FINAL 30s SUBTLE SEEKER HINT HELPERS
--------------------------------------------------------------------------------
local MAP_ZONE_NAMES: { [string]: { NE: string, NW: string, SW: string, SE: string, Center: string } } = {
	GrandPlaza = {
		Center = "น้ำพุโถงกลาง (Center)",
		NE = "โซนออฟฟิศ & ห้องสมุด",
		NW = "โซนโกดังสินค้า (Warehouse)",
		SW = "โซนตู้เกมอาร์เคด & คาเฟ่",
		SE = "โซนคลังขนส่ง (Logistics)",
	},
	CyberpunkMall = {
		Center = "โถงคริสตัลโฮโลแกรมกลางแมพ",
		NE = "ห้องเซิร์ฟเวอร์ (Server Vault)",
		NW = "ไซเบอร์เซกเตอร์ 01",
		SW = "โซนตู้เกมนีออน (Neon Lounge)",
		SE = "ตลาดไซเบอร์ (Night Market)",
	},
	SchoolCampus = {
		Center = "ลานตราสัญลักษณ์กลางโรงเรียน",
		NE = "โซนห้องเรียน (Classrooms)",
		NW = "โซนห้องสมุด & ล็อกเกอร์",
		SW = "โซนโรงอาหาร (Cafeteria)",
		SE = "โซนโรงยิมบาสเกตบอล",
	},
	CampingPark = {
		Center = "ลานหินกลางแคมป์",
		NE = "ลานกางเต็นท์ป่าสน",
		NW = "โซนสะพานลำธาร (Creek)",
		SW = "ป้อมเจ้าหน้าที่ (Ranger Outpost)",
		SE = "ลานกองไฟ (Campfire Grove)",
	},
	JapaneseVillage = {
		Center = "สะพานแดงสระปลาคราฟกลางแมพ",
		NE = "โรงน้ำชาทาทามิ (Tea House)",
		NW = "สวนหินเซน (Zen Garden)",
		SW = "ถนนร้านราเมง (Ramen Street)",
		SE = "ลานศาลเจ้าซากุระ",
	},
	MedievalCastle = {
		Center = "ลานดาบปักหินกลางปราสาท",
		NE = "ห้องโถงจัดเลี้ยงราชา",
		NW = "หอสมุดเวทมนตร์",
		SW = "ตลาดกลางปราสาท",
		SE = "โรงตีเหล็ก & คลังอาวุธ",
	},
}

local function getMapZoneHint(mapId: string, pos: Vector3): string
	local zones = MAP_ZONE_NAMES[mapId] or MAP_ZONE_NAMES.GrandPlaza
	if Vector2.new(pos.X, pos.Z).Magnitude <= 28 then
		return zones.Center
	end
	if pos.X >= 0 and pos.Z < 0 then
		return zones.NE
	elseif pos.X < 0 and pos.Z < 0 then
		return zones.NW
	elseif pos.X < 0 and pos.Z >= 0 then
		return zones.SW
	else
		return zones.SE
	end
end

local function getPropCategoryHint(propName: string): string
	if
		string.find(propName, "Crate")
		or string.find(propName, "Barrel")
		or string.find(propName, "Pallet")
		or string.find(propName, "Chest")
		or string.find(propName, "TrashBin")
	then
		return "กล่อง/ถัง/ของเก็บของ"
	elseif
		string.find(propName, "Tree")
		or string.find(propName, "Plant")
		or string.find(propName, "Bamboo")
	then
		return "ต้นไม้/พืชประดับ"
	elseif
		string.find(propName, "Desk")
		or string.find(propName, "Chair")
		or string.find(propName, "Sofa")
		or string.find(propName, "Table")
		or string.find(propName, "Bookshelf")
	then
		return "โต๊ะ/เก้าอี้/เฟอร์นิเจอร์"
	elseif
		string.find(propName, "Lantern")
		or string.find(propName, "Lamp")
		or string.find(propName, "Brazier")
		or string.find(propName, "Campfire")
		or string.find(propName, "Banner")
		or string.find(propName, "Cone")
	then
		return "โคมไฟ/ป้าย/ของตั้งพื้น"
	else
		return "ตู้/ซุ้ม/อุปกรณ์ใหญ่"
	end
end

local function sendSeekerFinalHint(mapId: string, includeCategory: boolean)
	local livingHiders: { { Player: Player, Root: BasePart, Char: Model } } = {}
	for p in activeHiders do
		if p.Parent == Players and p.Character then
			local root = p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local hum = p.Character:FindFirstChildOfClass("Humanoid")
			if root and hum and hum.Health > 0 then
				table.insert(livingHiders, { Player = p, Root = root, Char = p.Character })
			end
		end
	end

	if #livingHiders == 0 then
		return
	end

	-- Shuffle so if many Hiders remain we sample up to 4 subtle clues fairly
	for i = #livingHiders, 2, -1 do
		local j = math.random(1, i)
		livingHiders[i], livingHiders[j] = livingHiders[j], livingHiders[i]
	end

	local clues: { string } = {}
	local pings: { { Pos: Vector3, Zone: string } } = {}
	local maxClues = math.min(4, #livingHiders)

	for idx = 1, maxClues do
		local entry = livingHiders[idx]
		local pos = entry.Root.Position
		local zoneName = getMapZoneHint(mapId, pos)
		local rawSize = tostring(entry.Char:GetAttribute("PropSizeClass") or "Medium")
		local sizeThai = if rawSize == "Small"
			then "ของชิ้นเล็ก"
			elseif rawSize == "Large" then "ของชิ้นใหญ่"
			else "ของชิ้นกลาง"

		if includeCategory then
			local propName = tostring(entry.Char:GetAttribute("MorphedPropName") or "Prop")
			local category = getPropCategoryHint(propName)
			table.insert(clues, string.format("📍 %s • %s (%s)", zoneName, sizeThai, category))
		else
			table.insert(clues, string.format("📍 %s • %s", zoneName, sizeThai))
		end

		-- Offset ping center randomly by 9..14 studs so it hints the general area, NEVER the exact prop!
		local angle = math.random() * math.pi * 2
		local radiusOffset = 9 + math.random() * 5
		local approxX = math.clamp(pos.X + math.cos(angle) * radiusOffset, -106, 106)
		local approxZ = math.clamp(pos.Z + math.sin(angle) * radiusOffset, -106, 106)
		table.insert(pings, {
			Pos = Vector3.new(approxX, 0.2, approxZ),
			Zone = zoneName,
		})
	end

	local stageLabel = if includeCategory then "คำใบ้เสริม 15 วิสุดท้าย!" else "คำใบ้ 30 วิสุดท้าย!"
	for seeker in activeSeekers do
		if seeker.Parent == Players then
			roundEventNotice:FireClient(seeker, "SeekerFinalHint", {
				Title = stageLabel,
				AliveCount = #livingHiders,
				Clues = clues,
				Pings = pings,
			})
		end
	end

	if not includeCategory then
		for _, entry in livingHiders do
			roundEventNotice:FireClient(entry.Player, "HiderHintWarning", {
				Message = "⚠️ เหลือ 30 วิสุดท้าย! ฝ่ายหาได้รับคำใบ้โซนซ่อนตัวคร่าวๆ แล้ว!",
			})
		end
	end
end

local function setupPlayer(player: Player)
	player.Team = lobbyTeam
	if player:GetAttribute("OwnedSkins") == nil then
		player:SetAttribute("OwnedSkins", "Default")
	end
	if player:GetAttribute("EquippedSkin") == nil then
		player:SetAttribute("EquippedSkin", "Default")
	end

	-- Create leaderstats Folder and Coins/Wins/BestSurvival IntValues
	local leaderstats = player:FindFirstChild("leaderstats") :: Folder?
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	local coins = leaderstats:FindFirstChild("Coins") :: IntValue?
	if not coins then
		coins = Instance.new("IntValue")
		coins.Name = "Coins"
		coins.Value = 0
		coins.Parent = leaderstats
	end

	local wins = leaderstats:FindFirstChild("Wins") :: IntValue?
	if not wins then
		wins = Instance.new("IntValue")
		wins.Name = "Wins"
		wins.Value = 0
		wins.Parent = leaderstats
	end

	local bestSurvival = leaderstats:FindFirstChild("BestSurvival") :: IntValue?
	if not bestSurvival then
		bestSurvival = Instance.new("IntValue")
		bestSurvival.Name = "BestSurvival"
		bestSurvival.Value = 0
		bestSurvival.Parent = leaderstats
	end

	-- If a player dies during a round, remove them from active Hiders/Seekers and send to Lobby
	player.CharacterAdded:Connect(function(character: Model)
		local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
		if not humanoid then
			return
		end

		humanoid.Died:Connect(function()
			if activeHiders[player] then
				recordHiderSurvivalTime(player)
				activeHiders[player] = nil
				player.Team = lobbyTeam
				checkLastManStanding(false)
			elseif activeSeekers[player] then
				activeSeekers[player] = nil
				player.Team = lobbyTeam
			end
		end)
	end)
end

Players.PlayerAdded:Connect(setupPlayer)
for _, player in Players:GetPlayers() do
	setupPlayer(player)
end

Players.PlayerRemoving:Connect(function(player: Player)
	if activeHiders[player] then
		recordHiderSurvivalTime(player)
		activeHiders[player] = nil
		checkLastManStanding(false)
	end
	activeSeekers[player] = nil
end)

--------------------------------------------------------------------------------
-- 3. HELPER FUNCTIONS (SPAWNS, TELEPORT, STATE BROADCASTING)
--------------------------------------------------------------------------------
-- Broadcasts round state and timer via Workspace Attributes for client UIs
local function broadcastRoundState(state: string, timer: number, statusMessage: string?)
	workspace:SetAttribute("RoundState", state)
	workspace:SetAttribute("RoundTimer", timer)
	if statusMessage then
		workspace:SetAttribute("RoundStatus", statusMessage)
	end
end

-- Resolves the Map Spawn CFrame (looks for Workspace.MapSpawn or a folder Workspace.MapSpawns)
local function getMapSpawnCFrame(): CFrame
	local mapSpawnsFolder = workspace:FindFirstChild("MapSpawns")
	if mapSpawnsFolder then
		local children = mapSpawnsFolder:GetChildren()
		if #children > 0 then
			local randomSpawn = children[math.random(1, #children)]
			if randomSpawn:IsA("BasePart") then
				return randomSpawn.CFrame
			end
		end
	end

	local singleMapSpawn = workspace:FindFirstChild("MapSpawn")
	if singleMapSpawn and singleMapSpawn:IsA("BasePart") then
		return singleMapSpawn.CFrame
	end

	-- Fallback above origin if no MapSpawn part is placed yet
	return CFrame.new(0, 10, 0)
end

-- Resolves the Seeker Waiting Box CFrame (looks for Workspace.SeekerWaitingBox)
local function getSeekerWaitingCFrame(): CFrame
	local waitingBox = workspace:FindFirstChild("SeekerWaitingBox")
	if waitingBox and waitingBox:IsA("BasePart") then
		return waitingBox.CFrame
	end

	-- Fallback holding position
	return CFrame.new(0, 100, 0)
end

-- Safely teleports a player's character and sets Seeker WalkSpeed/JumpPower to 0 during Hiding Phase
local function teleportAndSetFreeze(player: Player, targetCFrame: CFrame, freezeAndBlind: boolean)
	local character = player.Character
	if not character then
		return
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")

	if rootPart then
		rootPart.AssemblyLinearVelocity = Vector3.zero
		rootPart.AssemblyAngularVelocity = Vector3.zero
		rootPart.CFrame = targetCFrame + Vector3.new(0, 3.5, 0)
		rootPart.Anchored = freezeAndBlind
	end

	if humanoid then
		humanoid.AutoRotate = not freezeAndBlind
		humanoid.UseJumpPower = true
		if freezeAndBlind then
			humanoid.WalkSpeed = 0
			humanoid.JumpPower = 0
		else
			local baseSpeed = if player:GetAttribute("HasSpeedPerk") == true then 20 else 16
			humanoid.WalkSpeed = baseSpeed
			humanoid.JumpPower = 50
		end
	end

	-- Set attribute so Client UI can show/hide the black blindfold overlay for the Seeker
	player:SetAttribute("IsBlindfolded", freezeAndBlind)
end

-- Counts how many players in a tracking dictionary are still in the server and alive
local function countAliveInSet(playerSet: { [Player]: boolean }): number
	local count = 0
	for player in playerSet do
		if player.Parent == Players and player.Character then
			local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				count += 1
			else
				playerSet[player] = nil
			end
		else
			playerSet[player] = nil
		end
	end
	return count
end

-- Awards 50 Coins and +1 Win to a list of winning players
local function awardWinners(winners: { Player }, amount: number)
	for _, player in winners do
		if player.Parent == Players then
			local leaderstats = player:FindFirstChild("leaderstats")
			if leaderstats then
				local coins = leaderstats:FindFirstChild("Coins") :: IntValue?
				if coins then
					coins.Value += amount
				end
				local wins = leaderstats:FindFirstChild("Wins") :: IntValue?
				if wins then
					wins.Value += 1
				end
			end
		end
	end
end

-- Resets everyone to the Lobby team and respawns normal avatars
local VALID_MAP_CHOICES = {
	GrandPlaza = true,
	CyberpunkMall = true,
	SchoolCampus = true,
	CampingPark = true,
	JapaneseVillage = true,
	MedievalCastle = true,
	Random = true,
}
local MAP_POOL = {
	"GrandPlaza",
	"CyberpunkMall",
	"SchoolCampus",
	"CampingPark",
	"JapaneseVillage",
	"MedievalCastle",
}
local playerMapVotes: { [Player]: string } = {}

local function tallyVotesAndGetLeadingChoice(): string
	local counts: { [string]: number } = {
		GrandPlaza = 0,
		CyberpunkMall = 0,
		SchoolCampus = 0,
		CampingPark = 0,
		JapaneseVillage = 0,
		MedievalCastle = 0,
		Random = 0,
	}

	for p, choice in playerMapVotes do
		if p.Parent == Players and counts[choice] ~= nil then
			counts[choice] += 1
		end
	end

	-- Broadcast vote tallies to Workspace attributes so LobbyUi updates live
	for key, count in counts do
		workspace:SetAttribute("Votes_" .. key, count)
	end

	local bestChoice = "Random"
	local highestCount = 0
	for _, option in {
		"GrandPlaza",
		"CyberpunkMall",
		"SchoolCampus",
		"CampingPark",
		"JapaneseVillage",
		"MedievalCastle",
		"Random",
	} do
		if counts[option] > highestCount then
			highestCount = counts[option]
			bestChoice = option
		end
	end

	workspace:SetAttribute("SelectedMapChoice", bestChoice)
	return bestChoice
end

local function applyPlayerMapVote(player: Player, mapChoice: string)
	if typeof(mapChoice) ~= "string" or not VALID_MAP_CHOICES[mapChoice] then
		return
	end
	if playerMapVotes[player] == mapChoice and player:GetAttribute("VotedMap") == mapChoice then
		return
	end

	playerMapVotes[player] = mapChoice
	player:SetAttribute("VotedMap", mapChoice)

	local leading = tallyVotesAndGetLeadingChoice()
	local currentState = workspace:GetAttribute("RoundState")
	-- If we are in WaitingForPlayers or Intermission and a specific map is leading, preview it live below the Skylight!
	if
		(currentState == "WaitingForPlayers" or currentState == "Intermission" or currentState == nil)
		and leading ~= "Random"
		and workspace:GetAttribute("ActiveMapId") ~= leading
	then
		MapBuilder.Generate(leading)
	end
end

voteMapEvent.OnServerEvent:Connect(applyPlayerMapVote)

-- Hook up physical 3D MapVotePads in SkyLoungeLobby (including if SkyLoungeLobby is rebuilt/upgraded!)
local function bindLobbyVotePads(lobby: Instance)
	task.spawn(function()
		local padsFolder = lobby:WaitForChild("MapVotePads", 10)
		if not padsFolder then
			return
		end

		local function bindPad(pad: Instance)
			if not pad:IsA("BasePart") or pad:GetAttribute("_VoteBound") then
				return
			end
			local choice = pad:GetAttribute("MapChoice")
			if typeof(choice) == "string" then
				pad:SetAttribute("_VoteBound", true)
				pad.Touched:Connect(function(hit: BasePart)
					local char = hit.Parent
					local player = char and Players:GetPlayerFromCharacter(char :: Model)
					if player then
						applyPlayerMapVote(player, choice)
					end
				end)
			end
		end

		for _, pad in padsFolder:GetChildren() do
			bindPad(pad)
		end
		padsFolder.ChildAdded:Connect(bindPad)
	end)
end

task.spawn(function()
	local gameMap = workspace:WaitForChild("GameMap", 15)
	if not gameMap then
		return
	end

	local existingLobby = gameMap:FindFirstChild("SkyLoungeLobby")
	if existingLobby then
		bindLobbyVotePads(existingLobby)
	end
	gameMap.ChildAdded:Connect(function(child: Instance)
		if child.Name == "SkyLoungeLobby" then
			bindLobbyVotePads(child)
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	playerMapVotes[player] = nil
	tallyVotesAndGetLeadingChoice()
end)

tallyVotesAndGetLeadingChoice()

local startGameRequested = false

local function getActiveParticipants(): { Player }
	local list: { Player } = {}
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("IsAFK") ~= true then
			table.insert(list, p)
		end
	end
	return list
end

startGameEvent.OnServerEvent:Connect(function(player: Player)
	-- Pressing Start automatically brings the player out of AFK so they can join the round!
	if player:GetAttribute("IsAFK") == true then
		player:SetAttribute("IsAFK", false)
	end
	local currentState = workspace:GetAttribute("RoundState")
	if currentState ~= "WaitingForPlayers" and currentState ~= nil then
		return
	end
	if #getActiveParticipants() < MIN_PLAYERS then
		return
	end
	startGameRequested = true
end)

local function cleanupRound()
	table.clear(activeHiders)
	table.clear(activeSeekers)
	table.clear(hiderRoundStartTimes)
	table.clear(playerMapVotes)
	lastManStandingTriggered = false
	startGameRequested = false

	-- Destroy any leftover HiderDecoyProps or SurvivorRevealBeacons from the previous round
	for _, child in workspace:GetChildren() do
		if child.Name == "HiderDecoyProp" or child.Name == "SurvivorRevealBeacon" then
			child:Destroy()
		end
	end

	for _, player in Players:GetPlayers() do
		player:SetAttribute("IsBlindfolded", false)
		player:SetAttribute("VotedMap", "Random")
		player:SetAttribute("RoundTauntCoins", 0)
		player:SetAttribute("RoundKills", 0)
		player:SetAttribute("LastRoundSurvival", 0)
		player.Team = lobbyTeam
		player:LoadCharacter()
	end

	tallyVotesAndGetLeadingChoice()
end

--------------------------------------------------------------------------------
-- 4. MAIN GAME LOOP
--------------------------------------------------------------------------------
task.spawn(function()
	while true do
		startGameRequested = false

		-- Wait until at least MIN_PLAYERS non-AFK players are ready AND someone presses the Start button!
		while true do
			local activeCount = #getActiveParticipants()
			if activeCount < MIN_PLAYERS then
				startGameRequested = false
				broadcastRoundState(
					"WaitingForPlayers",
					0,
					string.format("รอผู้เล่นพร้อม (%d/%d คน)...", activeCount, MIN_PLAYERS)
				)
			elseif not startGameRequested then
				broadcastRoundState(
					"WaitingForPlayers",
					0,
					"กดปุ่ม [เริ่มเกม] เพื่อเริ่มนับเวลาเลือกแมพ 30 วิ!"
				)
			else
				break
			end
			task.wait(0.25)
		end

		startGameRequested = false

		-- STATE 1: Intermission (30 seconds map voting countdown)
		local intermissionCompleted = true
		for remaining = INTERMISSION_TIME, 1, -1 do
			if #getActiveParticipants() < MIN_PLAYERS then
				intermissionCompleted = false
				break
			end
			broadcastRoundState("Intermission", remaining, string.format("เลือกแมพได้เลย! (%ds)", remaining))
			task.wait(1)
		end

		local participants = getActiveParticipants()
		if not intermissionCompleted or #participants < MIN_PLAYERS then
			continue
		end

		-- Resolve Map Vote & Always rebuild map so random clutter props change every round!
		local winningChoice = tallyVotesAndGetLeadingChoice()
		local finalMapId = if winningChoice == "Random"
			then MAP_POOL[math.random(1, #MAP_POOL)]
			else winningChoice

		MapBuilder.Generate(finalMapId)

		-- STATE 2: Role Selection (Scale Seekers by player count: ~1 Seeker per 4 players)
		table.clear(activeHiders)
		table.clear(activeSeekers)
		table.clear(hiderRoundStartTimes)
		lastManStandingTriggered = false

		-- Store all initial Hiders so even eliminated Hiders on the winning side can be rewarded, or reward surviving Hiders
		local roundHiderRoster: { Player } = {}
		local roundSeekerRoster: { Player } = {}

		-- Solo test: a single Studio player becomes a Hider (no Seeker) so morphing can be tested freely
		local isSoloTest = IS_TEST and #participants == 1
		local numSeekers = if isSoloTest
			then 0
			else math.clamp(math.floor((#participants + 2) / 4), 1, math.max(1, #participants - 1))

		-- Shuffle participants to pick random Seekers
		local shuffled: { Player } = table.clone(participants)
		for i = #shuffled, 2, -1 do
			local j = math.random(1, i)
			shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
		end

		for index, player in shuffled do
			player:SetAttribute("RoundTauntCoins", 0)
			player:SetAttribute("RoundKills", 0)
			player:SetAttribute("LastRoundSurvival", 0)
			if index <= numSeekers then
				player.Team = seekersTeam
				activeSeekers[player] = true
				table.insert(roundSeekerRoster, player)
			else
				player.Team = hidersTeam
				activeHiders[player] = true
				table.insert(roundHiderRoster, player)
			end

			-- Ensure fresh avatar before teleporting
			player:LoadCharacter()
		end

		-- Brief yield for characters to finish loading
		task.wait(0.5)

		-- Teleport Hiders to Map SpawnLocation, and freeze/blind Seekers in Waiting Box
		local seekerIdx = 0
		for player in activeHiders do
			teleportAndSetFreeze(player, getMapSpawnCFrame(), false)
		end
		for seeker in activeSeekers do
			local offset = Vector3.new((seekerIdx % 3) * 4 - 4, 0, math.floor(seekerIdx / 3) * 4)
			teleportAndSetFreeze(seeker, getSeekerWaitingCFrame() + offset, true)
			seekerIdx += 1
		end

		-- STATE 3: Hiding Phase (60 seconds in normal mode)
		for remaining = HIDING_PHASE_TIME, 1, -1 do
			if countAliveInSet(activeHiders) == 0 or (not isSoloTest and countAliveInSet(activeSeekers) == 0) then
				break
			end
			broadcastRoundState("HidingPhase", remaining, string.format("Hiders are Hiding! (%ds)", remaining))
			task.wait(1)
		end

		-- Release & Teleport Seekers into the Map and start Hider survival timers
		local huntingStartClock = os.clock()
		for hider in activeHiders do
			hiderRoundStartTimes[hider] = huntingStartClock
		end
		for seeker in activeSeekers do
			teleportAndSetFreeze(seeker, getMapSpawnCFrame(), false)
		end

		-- STATE 4: Hunting Phase (scaled by player count) & Continuous Win Condition Check
		local winningSide: "Seekers" | "Hiders" = "Hiders"
		local timeRemaining = getHuntingPhaseTime(#participants)
		local hint30Triggered = false
		local hint15Triggered = false

		while timeRemaining > 0 do
			broadcastRoundState(
				"HuntingPhase",
				 math.ceil(timeRemaining),
				string.format("Seekers are Hunting! (%ds)", math.ceil(timeRemaining))
			)

			if not hint30Triggered and timeRemaining <= 30 then
				hint30Triggered = true
				sendSeekerFinalHint(finalMapId, false)
			elseif not hint15Triggered and timeRemaining <= 15 then
				hint15Triggered = true
				sendSeekerFinalHint(finalMapId, true)
			end

			-- Continuous check every 0.25 seconds so wins trigger immediately
			local step = 0.25
			task.wait(step)
			timeRemaining -= step

			local aliveHidersCount = countAliveInSet(activeHiders)
			local aliveSeekersCount = countAliveInSet(activeSeekers)

			if aliveHidersCount == 1 then
				checkLastManStanding(isSoloTest)
			end

			if aliveHidersCount == 0 then
				-- All Hiders died or left -> Seekers win immediately!
				winningSide = "Seekers"
				break
			elseif aliveSeekersCount == 0 and not isSoloTest then
				-- Seekers died (e.g., from miss penalties) or left -> Hiders win immediately!
				winningSide = "Hiders"
				break
			end
		end

		-- Record survival time & collect surviving Hiders for the 15s Blinking Reveal!
		local survivingHiders: { Player } = {}
		local survivorNames: { string } = {}
		for hider in activeHiders do
			recordHiderSurvivalTime(hider)
			if hider.Parent == Players and hider.Character then
				local hum = hider.Character:FindFirstChildOfClass("Humanoid")
				if hum and hum.Health > 0 then
					table.insert(survivingHiders, hider)
					table.insert(survivorNames, hider.DisplayName)
				end
			end
		end

		-- STATE 5: Announce Winner, Award 50 Coins + 1 Win, Reveal Blinking Survivors for 15s, and Cleanup
		local bestHiderName = "-"
		local bestHiderTime = -1
		for _, h in roundHiderRoster do
			local surv = (h:GetAttribute("LastRoundSurvival") :: number?) or 0
			if surv > bestHiderTime then
				bestHiderTime = surv
				bestHiderName = h.DisplayName
			end
		end

		local bestSeekerName = "-"
		local bestSeekerKills = 0
		for _, s in roundSeekerRoster do
			local k = (s:GetAttribute("RoundKills") :: number?) or 0
			if k >= bestSeekerKills then
				bestSeekerKills = k
				bestSeekerName = s.DisplayName
			end
		end

		local postDuration = if #survivingHiders > 0 then SURVIVOR_REVEAL_TIME else NO_SURVIVOR_POST_TIME
		local winAnnouncement = if winningSide == "Seekers"
			then "ฝ่ายหาชนะ! (+50 Coins)"
			else string.format("ฝ่ายซ่อนชนะ! เฉลยผู้รอดชีวิต %d คน", #survivingHiders)

		if winningSide == "Seekers" then
			awardWinners(roundSeekerRoster, WIN_REWARD_COINS)
		else
			awardWinners(roundHiderRoster, WIN_REWARD_COINS)
		end

		broadcastRoundState("RoundOver", postDuration, winAnnouncement)

		roundEventNotice:FireAllClients("RoundSummary", {
			WinningSide = winningSide,
			BestHiderName = bestHiderName,
			BestHiderSurvival = math.max(0, bestHiderTime),
			BestSeekerName = bestSeekerName,
			BestSeekerKills = bestSeekerKills,
			RewardCoins = WIN_REWARD_COINS,
			SurvivorCount = #survivingHiders,
			SurvivorNames = table.concat(survivorNames, ", "),
			RevealDuration = postDuration,
		})

		-- Attach blinking Highlight + Overhead Nameplate + Sky Light Pillar to every surviving Hider!
		type BlinkTarget = {
			Character: Model,
			Root: BasePart,
			Highlight: Highlight,
			Beacon: Part,
			Parts: { { Part: BasePart, BaseTrans: number } },
		}
		local blinkTargets: { BlinkTarget } = {}

		for _, survivor in survivingHiders do
			local char = survivor.Character
			local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if not char or not root or not hum then
				continue
			end

			-- Unfreeze prop lock so survivors can celebrate or show off their hiding spot
			if root.Anchored then
				root.Anchored = false
				hum.AutoRotate = true
				char:SetAttribute("IsPropLocked", false)
			end

			local hl = Instance.new("Highlight")
			hl.Name = "SurvivorRevealHighlight"
			hl.Adornee = char
			hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			hl.FillColor = Color3.fromRGB(255, 220, 55)
			hl.OutlineColor = Color3.fromRGB(255, 255, 255)
			hl.FillTransparency = 0.08
			hl.OutlineTransparency = 0
			hl.Parent = char

			local propLabel = tostring(char:GetAttribute("MorphedPropName") or "Avatar")
			local tagGui = Instance.new("BillboardGui")
			tagGui.Name = "SurvivorRevealTag"
			tagGui.Adornee = root
			tagGui.Size = UDim2.fromOffset(200, 52)
			tagGui.StudsOffset = Vector3.new(0, 6.2, 0)
			tagGui.AlwaysOnTop = true
			tagGui.MaxDistance = 320
			tagGui.Parent = root

			local tagBg = Instance.new("Frame")
			tagBg.Size = UDim2.fromScale(1, 1)
			tagBg.BackgroundColor3 = Color3.fromRGB(16, 22, 36)
			tagBg.BackgroundTransparency = 0.08
			tagBg.BorderSizePixel = 0
			tagBg.Parent = tagGui

			local tagCorner = Instance.new("UICorner")
			tagCorner.CornerRadius = UDim.new(0, 12)
			tagCorner.Parent = tagBg

			local tagStroke = Instance.new("UIStroke")
			tagStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			tagStroke.Color = Color3.fromRGB(255, 215, 65)
			tagStroke.Thickness = 2
			tagStroke.Parent = tagBg

			local tagTitle = Instance.new("TextLabel")
			tagTitle.Size = UDim2.new(1, -12, 0, 24)
			tagTitle.Position = UDim2.fromOffset(6, 4)
			tagTitle.BackgroundTransparency = 1
			tagTitle.Font = Enum.Font.GothamBlack
			tagTitle.TextSize = 13
			tagTitle.TextTruncate = Enum.TextTruncate.AtEnd
			tagTitle.TextColor3 = Color3.fromRGB(255, 225, 75)
			tagTitle.Text = "🏆 รอดชีวิต: " .. survivor.DisplayName
			tagTitle.Parent = tagBg

			local tagSub = Instance.new("TextLabel")
			tagSub.Size = UDim2.new(1, -12, 0, 18)
			tagSub.Position = UDim2.fromOffset(6, 28)
			tagSub.BackgroundTransparency = 1
			tagSub.Font = Enum.Font.GothamBold
			tagSub.TextSize = 11
			tagSub.TextTruncate = Enum.TextTruncate.AtEnd
			tagSub.TextColor3 = Color3.fromRGB(95, 245, 165)
			tagSub.Text = "ซ่อนเป็น: " .. propLabel
			tagSub.Parent = tagBg

			-- Vertical Sky Light Beacon Pillar following the survivor
			local beacon = Instance.new("Part")
			beacon.Name = "SurvivorRevealBeacon"
			beacon.Shape = Enum.PartType.Cylinder
			beacon.Anchored = true
			beacon.CanCollide = false
			beacon.CanQuery = false
			beacon.CastShadow = false
			beacon.Material = Enum.Material.Neon
			beacon.Color = Color3.fromRGB(255, 220, 65)
			beacon.Transparency = 0.62
			beacon.Size = Vector3.new(28, 1.6, 1.6)
			beacon.CFrame = CFrame.new(root.Position + Vector3.new(0, 14, 0)) * CFrame.Angles(0, 0, math.rad(90))
			beacon.Parent = workspace

			local trackedParts: { { Part: BasePart, BaseTrans: number } } = {}
			local morphedProp = char:FindFirstChild("MorphedProp")
			local container: Instance = morphedProp or char
			for _, desc in container:GetDescendants() do
				if desc:IsA("BasePart") and desc.Name ~= "HumanoidRootPart" and desc.Transparency < 0.95 then
					table.insert(trackedParts, { Part = desc, BaseTrans = desc.Transparency })
				end
			end
			if container:IsA("BasePart") and container.Transparency < 0.95 then
				table.insert(trackedParts, { Part = container, BaseTrans = container.Transparency })
			end

			table.insert(blinkTargets, {
				Character = char,
				Root = root,
				Highlight = hl,
				Beacon = beacon,
				Parts = trackedParts,
			})
		end

		-- Blink survivors every 0.25s while updating the RoundOver countdown timer every second!
		local totalSteps = postDuration * 4
		for stepIdx = 1, totalSteps do
			local secsLeft = math.ceil((totalSteps - stepIdx + 1) / 4)
			local statusTxt = if #survivingHiders > 0
				then string.format("เฉลยผู้รอดชีวิต %d คน! กลับล็อบบี้ใน %ds", #survivingHiders, secsLeft)
				else string.format("%s (%ds)", winAnnouncement, secsLeft)
			broadcastRoundState("RoundOver", secsLeft, statusTxt)

			local blinkBright = (stepIdx % 2 == 1)
			local altEmerald = (stepIdx % 4 == 3)
			local flashCol = if altEmerald
				then Color3.fromRGB(75, 255, 165)
				else Color3.fromRGB(255, 220, 55)

			for _, bt in blinkTargets do
				if bt.Character.Parent and bt.Root.Parent then
					bt.Highlight.FillColor = flashCol
					bt.Highlight.FillTransparency = if blinkBright then 0.06 else 0.78
					bt.Highlight.OutlineTransparency = if blinkBright then 0 else 0.55

					if bt.Beacon.Parent then
						bt.Beacon.Color = flashCol
						bt.Beacon.Transparency = if blinkBright then 0.52 else 0.88
						bt.Beacon.CFrame = CFrame.new(bt.Root.Position + Vector3.new(0, 14, 0))
							* CFrame.Angles(0, 0, math.rad(90))
					end

					for _, pInfo in bt.Parts do
						if pInfo.Part.Parent then
							pInfo.Part.Transparency = if blinkBright
								then pInfo.BaseTrans
								else math.min(0.65, pInfo.BaseTrans + 0.45)
						end
					end
				end
			end

			task.wait(0.25)
		end

		-- Reset all players back to normal avatars and move everyone to Lobby team
		cleanupRound()
	end
end)

