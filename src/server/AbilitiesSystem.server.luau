--!strict
-- ServerScriptService/Server/AbilitiesSystem.server.luau
-- Adds tactical abilities for both Hiders and Seekers during the Hunting Phase:
-- 1. Hider Decoy Clone ([G] Key, Costs 20 Coins): Spawns a physical "Morphable" decoy of the Hider's current prop.
-- 2. Hider Smoke Sprint ([LeftShift] Key, 18s Cooldown): Drops a smoke cloud and grants a 3.5s speed boost (WalkSpeed 26) to escape.
-- 3. Seeker Sonar Radar ([Q] Key, 15s Cooldown): Emits an expanding neon scan ring and pings distance to the nearest living Hider.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Teams = game:GetService("Teams")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local PropRemotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PropRemotes"))
local abilityRequestEvent = PropRemotes.AbilityRequest
local radarFeedbackEvent = PropRemotes.RadarFeedback

-- Ability Constants
local DECOY_COST_COINS = 20
local DECOY_COOLDOWN = 12.0
local DECOY_LIFETIME = 45.0

local SPRINT_COOLDOWN = 18.0
local SPRINT_DURATION = 3.5
local SPRINT_WALKSPEED = 26
local DEFAULT_WALKSPEED = 16

local RADAR_COOLDOWN = 15.0

local MORPH_TAG = "Morphable"
local ACTIVE_PROP_NAME = "MorphedProp"

local decoyCooldowns: { [Player]: number } = {}
local sprintCooldowns: { [Player]: number } = {}
local radarCooldowns: { [Player]: number } = {}

-- Helper: Get alive character, rootPart, and humanoid
local function getAliveCharacter(player: Player): (Model?, BasePart?, Humanoid?)
	local character = player.Character
	if not character then
		return nil, nil, nil
	end
	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not rootPart or not humanoid or humanoid.Health <= 0 then
		return nil, nil, nil
	end
	return character, rootPart, humanoid
end

--------------------------------------------------------------------------------
-- ABILITY 1: HIDER DECOY CLONE ([G] Key, Costs 20 Coins)
--------------------------------------------------------------------------------
local function handleSpawnDecoy(hider: Player)
	local hidersTeam = Teams:FindFirstChild("Hiders")
	if hidersTeam and hider.Team ~= hidersTeam then
		return
	end

	local now = os.clock()
	if decoyCooldowns[hider] and (now - decoyCooldowns[hider]) < DECOY_COOLDOWN then
		return
	end

	local character, _rootPart, _humanoid = getAliveCharacter(hider)
	if not character then
		return
	end

	local currentProp = character:FindFirstChild(ACTIVE_PROP_NAME)
	if not currentProp then
		return
	end

	-- Check and deduct 20 Coins from leaderstats
	local leaderstats = hider:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("Coins") :: IntValue?
	if not coins or coins.Value < DECOY_COST_COINS then
		return
	end

	coins.Value -= DECOY_COST_COINS
	decoyCooldowns[hider] = now

	-- Clone the Hider's current prop into Workspace as an anchored "Morphable" decoy!
	local decoy = currentProp:Clone()
	decoy.Name = "HiderDecoyProp"

	if decoy:IsA("BasePart") then
		for _, child in decoy:GetChildren() do
			if child:IsA("WeldConstraint") then
				child:Destroy()
			end
		end
		decoy.Anchored = true
		decoy.CanCollide = true
		decoy.CanQuery = true
	elseif decoy:IsA("Model") then
		for _, desc in decoy:GetDescendants() do
			if desc:IsA("WeldConstraint") then
				desc:Destroy()
			elseif desc:IsA("BasePart") then
				desc.Anchored = true
				desc.CanCollide = true
				desc.CanQuery = true
			end
		end
	end

	-- Tag with "Morphable" so Seekers take the 15 HP penalty if they attack the decoy!
	CollectionService:AddTag(decoy, MORPH_TAG)
	decoy.Parent = workspace
	Debris:AddItem(decoy, DECOY_LIFETIME)
end

--------------------------------------------------------------------------------
-- ABILITY 2: HIDER SMOKE SPRINT ([LeftShift] Key, 18s Cooldown)
--------------------------------------------------------------------------------
local function handleSmokeSprint(hider: Player)
	local hidersTeam = Teams:FindFirstChild("Hiders")
	if hidersTeam and hider.Team ~= hidersTeam then
		return
	end

	local now = os.clock()
	if sprintCooldowns[hider] and (now - sprintCooldowns[hider]) < SPRINT_COOLDOWN then
		return
	end

	local character, rootPart, humanoid = getAliveCharacter(hider)
	if not character or not rootPart or not humanoid then
		return
	end

	sprintCooldowns[hider] = now

	-- Automatically unlock prop if anchored so the Hider can dash away immediately
	if rootPart.Anchored then
		rootPart.Anchored = false
		humanoid.AutoRotate = true
		character:SetAttribute("IsPropLocked", false)
	end

	-- Spawn a smoke puff at the Hider's position
	local smokeAnchor = Instance.new("Part")
	smokeAnchor.Size = Vector3.new(1, 1, 1)
	smokeAnchor.Position = rootPart.Position
	smokeAnchor.Anchored = true
	smokeAnchor.CanCollide = false
	smokeAnchor.CanQuery = false
	smokeAnchor.Transparency = 1
	smokeAnchor.Parent = workspace

	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(Color3.fromRGB(200, 205, 215))
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 3),
		NumberSequenceKeypoint.new(1, 9),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(1.2, 2.0)
	emitter.Rate = 0
	emitter.Speed = NumberRange.new(8, 16)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Parent = smokeAnchor
	emitter:Emit(35)
	Debris:AddItem(smokeAnchor, 2.5)

	-- Grant speed boost for 3.5 seconds
	humanoid.WalkSpeed = SPRINT_WALKSPEED
	task.delay(SPRINT_DURATION, function()
		if humanoid and humanoid.Parent and humanoid.Health > 0 then
			humanoid.WalkSpeed = DEFAULT_WALKSPEED
		end
	end)
end

--------------------------------------------------------------------------------
-- ABILITY 3: SEEKER SONAR RADAR ([Q] Key, 15s Cooldown)
--------------------------------------------------------------------------------
local function handleSeekerRadar(seeker: Player)
	if workspace:GetAttribute("RoundState") ~= "HuntingPhase" then
		return
	end

	local seekersTeam = Teams:FindFirstChild("Seekers")
	if seekersTeam and seeker.Team ~= seekersTeam then
		return
	end

	local now = os.clock()
	if radarCooldowns[seeker] and (now - radarCooldowns[seeker]) < RADAR_COOLDOWN then
		return
	end

	local _character, seekerRoot, _humanoid = getAliveCharacter(seeker)
	if not seekerRoot then
		return
	end

	radarCooldowns[seeker] = now

	-- Visual expanding neon ring around the Seeker
	local ring = Instance.new("Part")
	ring.Name = "SeekerSonarRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(255, 90, 90)
	ring.Size = Vector3.new(0.2, 2, 2)
	ring.CFrame = CFrame.new(seekerRoot.Position - Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.Transparency = 0.25
	ring.Parent = workspace

	TweenService:Create(
		ring,
		TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(0.2, 65, 65), Transparency = 1 }
	):Play()
	Debris:AddItem(ring, 1.05)

	-- Find distance to nearest alive Hider
	local hidersTeam = Teams:FindFirstChild("Hiders")
	local nearestDistance = math.huge

	for _, player in Players:GetPlayers() do
		if player ~= seeker and (not hidersTeam or player.Team == hidersTeam) then
			local _hChar, hRoot, _hHum = getAliveCharacter(player)
			if hRoot then
				local dist = (seekerRoot.Position - hRoot.Position).Magnitude
				if dist < nearestDistance then
					nearestDistance = dist
				end
			end
		end
	end

	local message: string
	if nearestDistance == math.huge then
		message = "RADAR: No Hiders found!"
	elseif nearestDistance <= 22 then
		message = string.format("RADAR: HOT! Hider within %d studs!", math.round(nearestDistance))
	elseif nearestDistance <= 50 then
		message = string.format("RADAR: WARM — Nearest Hider is ~%d studs away", math.round(nearestDistance))
	else
		message = string.format("RADAR: COLD — Nearest Hider is %d+ studs away", math.round(nearestDistance))
	end

	radarFeedbackEvent:FireClient(seeker, message, nearestDistance)
end

-- Route Ability & Lobby Shop Requests
local function applyPlayerPerks(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
	if not humanoid then
		return
	end

	if player:GetAttribute("HasSpeedPerk") == true and humanoid.WalkSpeed > 0 then
		humanoid.WalkSpeed = 20
	end

	if player:GetAttribute("HasHealthPerk") == true then
		humanoid.MaxHealth = 150
		humanoid.Health = 150
	end
end

Players.PlayerAdded:Connect(function(player: Player)
	player.CharacterAdded:Connect(function(character: Model)
		task.defer(applyPlayerPerks, player, character)
	end)
end)
for _, p in Players:GetPlayers() do
	p.CharacterAdded:Connect(function(character: Model)
		task.defer(applyPlayerPerks, p, character)
	end)
end

abilityRequestEvent.OnServerEvent:Connect(function(player: Player, abilityName: string)
	if typeof(abilityName) ~= "string" then
		return
	end

	if abilityName == "SpawnDecoy" then
		handleSpawnDecoy(player)
	elseif abilityName == "SmokeSprint" then
		handleSmokeSprint(player)
	elseif abilityName == "SeekerRadar" then
		handleSeekerRadar(player)
	elseif abilityName == "BuySpeedPerk" then
		if player:GetAttribute("HasSpeedPerk") == true then
			return
		end
		local leaderstats = player:FindFirstChild("leaderstats")
		local coins = leaderstats and leaderstats:FindFirstChild("Coins") :: IntValue?
		if coins and coins.Value >= 30 then
			coins.Value -= 30
			player:SetAttribute("HasSpeedPerk", true)
			if player.Character then
				applyPlayerPerks(player, player.Character)
			end
		end
	elseif abilityName == "BuyHealthPerk" then
		if player:GetAttribute("HasHealthPerk") == true then
			return
		end
		local leaderstats = player:FindFirstChild("leaderstats")
		local coins = leaderstats and leaderstats:FindFirstChild("Coins") :: IntValue?
		if coins and coins.Value >= 40 then
			coins.Value -= 40
			player:SetAttribute("HasHealthPerk", true)
			if player.Character then
				applyPlayerPerks(player, player.Character)
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player: Player)
	decoyCooldowns[player] = nil
	sprintCooldowns[player] = nil
	radarCooldowns[player] = nil
end)

