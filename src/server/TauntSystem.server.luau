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
local MANUAL_TAUNT_REWARD = 10 -- +10 Coins for manual taunt
local AUTO_TAUNT_INTERVAL = 30.0 -- Every 30 seconds during Hunting Phase
local EXCLAMATION_DURATION = 1.5 -- 1.5 seconds floating "!" indicator
local HIDERS_TEAM_NAME = "Hiders"

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

-- Helper: Show a floating "!" BillboardGui above the Hider for 1.5 seconds
local function showExclamationBillboard(rootPart: BasePart)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "TauntExclamationGui"
	billboard.Adornee = rootPart
	billboard.Size = UDim2.new(0, 64, 0, 64)
	billboard.StudsOffset = Vector3.new(0, 4.5, 0)
	billboard.AlwaysOnTop = false -- Respects walls unless Seeker has line-of-sight
	billboard.MaxDistance = 80
	billboard.Parent = rootPart

	local badge = Instance.new("Frame")
	badge.Size = UDim2.fromScale(0.8, 0.8)
	badge.Position = UDim2.fromScale(0.5, 0.5)
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
		end
	end)

	Debris:AddItem(billboard, EXCLAMATION_DURATION)
end

-- Helper: Award Coins to Hider's leaderstats
local function awardTauntCoins(player: Player, amount: number)
	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("Coins") :: IntValue?
	if coins then
		coins.Value += amount
	end
end

--------------------------------------------------------------------------------
-- 1. MANUAL TAUNT HANDLER (Risk vs. Reward)
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

	-- Play 3D sound, display 1.5s floating "!" BillboardGui, and award +10 Coins
	playTauntSound(rootPart)
	showExclamationBillboard(rootPart)
	awardTauntCoins(player, MANUAL_TAUNT_REWARD)
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

