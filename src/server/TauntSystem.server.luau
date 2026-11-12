--!strict
-- ServerScriptService/Server/TauntSystem.server.luau
-- Complete Hider Taunt System:
-- 1. Manual Taunt (T Key / Mobile Button): 10s cooldown, plays random 3D sound (RollOffMaxDistance = 80),
--    shows a floating "!" BillboardGui above the Hider for 1.5 seconds, and awards +10 Coins.
-- 2. Auto-Taunt (Anti-Camp): Automatically plays a random 3D taunt sound on all living Hiders every 30 seconds
--    during the Hunting Phase (without awarding bonus coins).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local PropRemotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PropRemotes"))
local tauntRequestEvent = PropRemotes.TauntRequest

-- Constants
local MANUAL_TAUNT_COOLDOWN = 10.0 -- 10-second cooldown per player
local MAX_TAUNT_COINS_PER_ROUND = 50 -- Cap taunt coin rewards per round
local AUTO_TAUNT_INTERVAL = 30.0 -- Every 30 seconds during Hunting Phase
local EXCLAMATION_DURATION = 1.5 -- 1.5 seconds floating "!" indicator
local HIDERS_TEAM_NAME = "Hiders"
local SEEKERS_TEAM_NAME = "Seekers"

-- 5 Default Valid Roblox Sound Asset IDs (Whistle, Boing, Horn, Laugh, Slide Whistle)
local TAUNT_SOUND_IDS = {
	"rbxassetid://9114074403", -- Classic Whistle
	"rbxassetid://12222124", -- Cartoon Boing / Spring
	"rbxassetid://9119713951", -- Party / Clown Horn
	"rbxassetid://9118823108", -- Goofy Chuckle / Laugh
	"rbxassetid://9114074147", -- Double Slide Whistle
}

-- Cooldown tracker per Hider
local manualTauntCooldowns: { [Player]: number } = {}

-- Helper: Verify the player is an alive Hider
local function getAliveHiderRoot(player: Player): (boolean, Model?, BasePart?)
	local hidersTeam = Teams:FindFirstChild(HIDERS_TEAM_NAME)
	if hidersTeam and player.Team ~= hidersTeam then
		return false, nil, nil
	end

	local character = player.Character
	if not character then
		return false, nil, nil
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not rootPart or not humanoid or humanoid.Health <= 0 then
		return false, nil, nil
	end

	return true, character, rootPart
end

-- Helper: Play a random 3D Taunt Sound parented to the Hider's HumanoidRootPart
local function playTauntSound(rootPart: BasePart)
	local sound = Instance.new("Sound")
	sound.Name = "HiderTauntSound"
	sound.SoundId = TAUNT_SOUND_IDS[math.random(1, #TAUNT_SOUND_IDS)]
	sound.Volume = 1.25
	sound.RollOffMinDistance = 8
	sound.RollOffMaxDistance = 80 -- Nearby Seekers within 80 studs can hear the direction
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.Parent = rootPart
	sound:Play()

	Debris:AddItem(sound, 5)
end

-- Helper: Calculate distance-based Taunt Coin reward (closer to Seekers = higher reward!)
local function getNearestSeekerDistance(hiderPos: Vector3): number
	local seekersTeam = Teams:FindFirstChild(SEEKERS_TEAM_NAME)
	local minDist = math.huge
	for _, p in Players:GetPlayers() do
		if seekersTeam and p.Team == seekersTeam and p.Character then
			local root = p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local hum = p.Character:FindFirstChildOfClass("Humanoid")
			if root and hum and hum.Health > 0 then
				local d = (hiderPos - root.Position).Magnitude
				if d < minDist then
					minDist = d
				end
			end
		end
	end
	return minDist
end

-- Helper: Show floating "+X Coins" feedback on the Hider's exclamation badge
local function showExclamationBillboard(rootPart: BasePart, coinsEarned: number)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "TauntExclamationGui"
	billboard.Adornee = rootPart
	billboard.Size = UDim2.new(0, 80, 0, 74)
	billboard.StudsOffset = Vector3.new(0, 4.5, 0)
	billboard.AlwaysOnTop = false -- Respects walls unless Seeker has line-of-sight
	billboard.MaxDistance = 80
	billboard.Parent = rootPart

	local badge = Instance.new("Frame")
	badge.Size = UDim2.new(0, 52, 0, 52)
	badge.Position = UDim2.fromScale(0.5, 0.42)
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	badge.BackgroundColor3 = Color3.fromRGB(255, 210, 45)
	badge.BorderSizePixel = 0
	badge.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = badge

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Thickness = 2.5
	stroke.Parent = badge

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(30, 25, 15)
	label.Text = "!"
	label.Parent = badge

	local coinText = Instance.new("TextLabel")
	coinText.Size = UDim2.new(1, 0, 0, 18)
	coinText.Position = UDim2.fromScale(0.5, 0.88)
	coinText.AnchorPoint = Vector2.new(0.5, 0.5)
	coinText.BackgroundTransparency = 1
	coinText.Font = Enum.Font.GothamBlack
	coinText.TextSize = 13
	coinText.TextColor3 = Color3.fromRGB(85, 255, 130)
	coinText.TextStrokeTransparency = 0.2
	coinText.Text = if coinsEarned > 0 then string.format("+%d Coins", coinsEarned) else "MAX (50/50)"
	coinText.Parent = billboard

	-- Pop-up bounce animation
	TweenService:Create(
		billboard,
		TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ StudsOffset = Vector3.new(0, 5.8, 0) }
	):Play()

	-- Fade out right before the 1.5-second duration ends
	task.delay(EXCLAMATION_DURATION - 0.3, function()
		if badge.Parent then
			TweenService:Create(badge, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
			TweenService:Create(label, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
			TweenService:Create(stroke, TweenInfo.new(0.3), { Transparency = 1 }):Play()
			TweenService:Create(coinText, TweenInfo.new(0.3), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)

	Debris:AddItem(billboard, EXCLAMATION_DURATION)
end

-- Helper: Award Coins to Hider's leaderstats based on Seeker distance and per-round cap
local function calculateAndAwardTauntCoins(player: Player, rootPos: Vector3): number
	local earnedSoFar = (player:GetAttribute("RoundTauntCoins") :: number?) or 0
	if earnedSoFar >= MAX_TAUNT_COINS_PER_ROUND then
		return 0
	end

	local dist = getNearestSeekerDistance(rootPos)
	local baseReward = if dist <= 25
		then 20 -- High risk: Seeker is right next to you!
		elseif dist <= 55 then 12 -- Medium risk: Seeker is within earshot
		else 5 -- Low risk: Seeker is far away

	local actualReward = math.min(baseReward, MAX_TAUNT_COINS_PER_ROUND - earnedSoFar)
	if actualReward <= 0 then
		return 0
	end

	player:SetAttribute("RoundTauntCoins", earnedSoFar + actualReward)

	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("Coins") :: IntValue?
	if coins then
		coins.Value += actualReward
	end
	return actualReward
end

--------------------------------------------------------------------------------
-- 1. MANUAL TAUNT HANDLER (Risk vs. Reward: Distance-scaled + 50 Coins/round cap)
--------------------------------------------------------------------------------
tauntRequestEvent.OnServerEvent:Connect(function(player: Player)
	-- Only allow manual taunts during the Hunting Phase
	if workspace:GetAttribute("RoundState") ~= "HuntingPhase" then
		return
	end

	-- Enforce 10-second cooldown per player
	local now = os.clock()
	if manualTauntCooldowns[player] and (now - manualTauntCooldowns[player]) < MANUAL_TAUNT_COOLDOWN then
		return
	end

	local isAliveHider, _character, rootPart = getAliveHiderRoot(player)
	if not isAliveHider or not rootPart then
		return
	end

	manualTauntCooldowns[player] = now

	-- Play 3D sound, award distance-based Coins (up to 50/round), and display floating "!" BillboardGui
	playTauntSound(rootPart)
	local rewarded = calculateAndAwardTauntCoins(player, rootPart.Position)
	showExclamationBillboard(rootPart, rewarded)
end)

--------------------------------------------------------------------------------
-- 2. AUTO-TAUNT LOOP (Anti-Camp: Every 30s during Hunting Phase, 0 Bonus Coins)
--------------------------------------------------------------------------------
task.spawn(function()
	local elapsedHuntingTime = 0

	while true do
		task.wait(1)

		if workspace:GetAttribute("RoundState") == "HuntingPhase" then
			elapsedHuntingTime += 1

			if elapsedHuntingTime >= AUTO_TAUNT_INTERVAL then
				elapsedHuntingTime = 0

				-- Trigger a 3D taunt sound on all living Hiders (no bonus coins)
				for _, player in Players:GetPlayers() do
					local isAliveHider, _char, rootPart = getAliveHiderRoot(player)
					if isAliveHider and rootPart then
						playTauntSound(rootPart)
					end
				end
			end
		else
			-- Reset timer whenever we are not in the Hunting Phase
			elapsedHuntingTime = 0
		end
	end
end)

Players.PlayerRemoving:Connect(function(player: Player)
	manualTauntCooldowns[player] = nil
end)

