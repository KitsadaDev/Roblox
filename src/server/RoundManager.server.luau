--!strict
-- ServerScriptService/Server/RoundManager.server.luau
-- Complete Round Management System: Teams Setup, Leaderstats (Coins), Game Loop States, Win Conditions, and Cleanup.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")
local RunService = game:GetService("RunService")

local PropRemotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PropRemotes"))
local voteMapEvent = PropRemotes.VoteMapRequest
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
local INTERMISSION_TIME = if IS_TEST then 14 else 20
local HIDING_PHASE_TIME = if IS_TEST then 10 else 60
local POST_ROUND_TIME = 5
local WIN_REWARD_COINS = 50

local function getHuntingPhaseTime(playerCount: number): number
	if IS_TEST then
		return 60
	end
	if playerCount <= 8 then
		return 300 -- 5 minutes (2-8 players)
	elseif playerCount <= 20 then
		return 480 -- 8 minutes (9-20 players)
	else
		return 720 -- 12 minutes (21+ players)
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
	Random = true,
}
local MAP_POOL = { "GrandPlaza", "CyberpunkMall", "SchoolCampus", "CampingPark" }
local playerMapVotes: { [Player]: string } = {}

local function tallyVotesAndGetLeadingChoice(): string
	local counts: { [string]: number } = {
		GrandPlaza = 0,
		CyberpunkMall = 0,
		SchoolCampus = 0,
		CampingPark = 0,
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
	for _, option in { "GrandPlaza", "CyberpunkMall", "SchoolCampus", "CampingPark", "Random" } do
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

-- Hook up physical 3D MapVotePads in SkyLoungeLobby so stepping on a pad also casts a vote!
task.spawn(function()
	local gameMap = workspace:WaitForChild("GameMap", 15)
	local lobby = gameMap and gameMap:WaitForChild("SkyLoungeLobby", 15)
	local padsFolder = lobby and lobby:WaitForChild("MapVotePads", 15)
	if not padsFolder then
		return
	end

	for _, pad in padsFolder:GetChildren() do
		if pad:IsA("BasePart") then
			local choice = pad:GetAttribute("MapChoice")
			if typeof(choice) == "string" then
				pad.Touched:Connect(function(hit: BasePart)
					local char = hit.Parent
					local player = char and Players:GetPlayerFromCharacter(char :: Model)
					if player then
						applyPlayerMapVote(player, choice)
					end
				end)
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player: Player)
	playerMapVotes[player] = nil
	tallyVotesAndGetLeadingChoice()
end)

tallyVotesAndGetLeadingChoice()

local function getActiveParticipants(): { Player }
	local list: { Player } = {}
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("IsAFK") ~= true then
			table.insert(list, p)
		end
	end
	return list
end

local function cleanupRound()
	table.clear(activeHiders)
	table.clear(activeSeekers)
	table.clear(hiderRoundStartTimes)
	table.clear(playerMapVotes)
	lastManStandingTriggered = false

	-- Destroy any leftover HiderDecoyProps from the previous round
	for _, child in workspace:GetChildren() do
		if child.Name == "HiderDecoyProp" then
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
		-- Wait until at least MIN_PLAYERS non-AFK players are in the server
		while #getActiveParticipants() < MIN_PLAYERS do
			broadcastRoundState("WaitingForPlayers", 0, "Waiting for active players...")
			task.wait(1)
		end

		-- STATE 1: Intermission
		local intermissionCompleted = true
		for remaining = INTERMISSION_TIME, 1, -1 do
			if #getActiveParticipants() < MIN_PLAYERS then
				intermissionCompleted = false
				break
			end
			broadcastRoundState("Intermission", remaining, string.format("Intermission - เลือกแมพได้! (%ds)", remaining))
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

		while timeRemaining > 0 do
			broadcastRoundState(
				"HuntingPhase",
				 math.ceil(timeRemaining),
				string.format("Seekers are Hunting! (%ds)", math.ceil(timeRemaining))
			)

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

		-- Record survival time for all remaining alive Hiders
		for hider in activeHiders do
			recordHiderSurvivalTime(hider)
		end

		-- STATE 5: Announce Winner, Award 50 Coins + 1 Win, Broadcast Round Summary MVP Card, and Cleanup
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

		if winningSide == "Seekers" then
			broadcastRoundState("RoundOver", POST_ROUND_TIME, "Seekers Win! (+50 Coins)")
			awardWinners(roundSeekerRoster, WIN_REWARD_COINS)
		else
			broadcastRoundState("RoundOver", POST_ROUND_TIME, "Hiders Win! (+50 Coins)")
			-- Award 50 Coins to the Hiders side
			awardWinners(roundHiderRoster, WIN_REWARD_COINS)
		end

		roundEventNotice:FireAllClients("RoundSummary", {
			WinningSide = winningSide,
			BestHiderName = bestHiderName,
			BestHiderSurvival = math.max(0, bestHiderTime),
			BestSeekerName = bestSeekerName,
			BestSeekerKills = bestSeekerKills,
			RewardCoins = WIN_REWARD_COINS,
		})

		task.wait(POST_ROUND_TIME)

		-- Reset all players back to normal avatars and move everyone to Lobby team
		cleanupRound()
	end
end)

