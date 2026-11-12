--!strict
-- ServerScriptService/Server/SeekerCombat.server.luau
-- Handles Seeker attacks (Case A: 50 dmg + highlight to Hiders, Case B: 15 self-damage on real Morphable props, Case C: nothing on walls/floors).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Teams = game:GetService("Teams")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local PropRemotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PropRemotes"))
local seekerAttackEvent = PropRemotes.SeekerAttackRequest
local roundEventNotice = PropRemotes.RoundEventNotice

-- Combat Constants
local MAX_ATTACK_DISTANCE = 10 -- 10 studs max range
local ATTACK_COOLDOWN = 1.0 -- 1-second server cooldown
local HIDER_HIT_DAMAGE = 50 -- Case A: Damage dealt to a Hider
local SEEKER_MISS_PENALTY = 15 -- Case B: Health penalty when hitting a real Morphable object
local SEEKER_KILL_BOUNTY_COINS = 15 -- Coins awarded to Seeker per Hider eliminated

local MORPH_TAG = "Morphable"
local SEEKERS_TEAM_NAME = "Seekers"
local HIDERS_TEAM_NAME = "Hiders"

local lastAttackTime: { [Player]: number } = {}

-- Helper: Verify the player is on the Seekers team and alive
local function getValidSeeker(player: Player): (boolean, Model?, BasePart?, Humanoid?)
	local seekersTeam = Teams:FindFirstChild(SEEKERS_TEAM_NAME)
	if seekersTeam and player.Team ~= seekersTeam then
		return false, nil, nil, nil
	end

	local character = player.Character
	if not character then
		return false, nil, nil, nil
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not rootPart or not humanoid or humanoid.Health <= 0 then
		return false, nil, nil, nil
	end

	return true, character, rootPart, humanoid
end

-- Helper (Case A Check): Resolve if hitInstance belongs to a Hider or their attached prop
local function getHiderFromHit(hitInstance: Instance): (Player?, Model?, Humanoid?, BasePart?)
	local hidersTeam = Teams:FindFirstChild(HIDERS_TEAM_NAME)
	local current: Instance? = hitInstance

	while current and current ~= workspace do
		if current:IsA("Model") then
			local hitPlayer = Players:GetPlayerFromCharacter(current)
			if hitPlayer then
				if not hidersTeam or hitPlayer.Team == hidersTeam then
					local humanoid = current:FindFirstChildOfClass("Humanoid")
					local rootPart = current:FindFirstChild("HumanoidRootPart") :: BasePart?
					if humanoid and humanoid.Health > 0 and rootPart then
						return hitPlayer, current, humanoid, rootPart
					end
				end
			end
		end
		current = current.Parent
	end

	return nil, nil, nil, nil
end

-- Helper (Case B Check): Check if hitInstance is a real "Morphable" object in Workspace (not a player)
local function isRealMorphableProp(hitInstance: Instance): boolean
	local current: Instance? = hitInstance
	while current and current ~= workspace do
		if current:IsA("Model") and Players:GetPlayerFromCharacter(current) then
			return false
		end

		if CollectionService:HasTag(current, MORPH_TAG) then
			return true
		end
		current = current.Parent
	end
	return false
end

-- Helper: Equip a procedural Neon Scanner Bat Tool when a player spawns on the Seekers team
local function giveSeekerBatonTool(player: Player, character: Model)
	local seekersTeam = Teams:FindFirstChild(SEEKERS_TEAM_NAME)
	if not seekersTeam or player.Team ~= seekersTeam then
		return
	end

	if character:FindFirstChild("SeekerScannerBaton") then
		return
	end

	local tool = Instance.new("Tool")
	tool.Name = "SeekerScannerBaton"
	tool.ToolTip = "คลิกซ้ายเพื่อโจมตี Prop ที่สงสัย!"
	tool.RequiresHandle = true
	tool.CanBeDropped = false

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.4, 3.2, 0.4)
	handle.Color = Color3.fromRGB(35, 38, 48)
	handle.Material = Enum.Material.Metal
	handle.CanCollide = false
	handle.CanQuery = false
	handle.Massless = true
	handle.Parent = tool

	local neonTip = Instance.new("Part")
	neonTip.Name = "NeonTip"
	neonTip.Size = Vector3.new(0.5, 1.4, 0.5)
	neonTip.Color = Color3.fromRGB(255, 65, 85)
	neonTip.Material = Enum.Material.Neon
	neonTip.CanCollide = false
	neonTip.CanQuery = false
	neonTip.Massless = true
	neonTip.CFrame = handle.CFrame * CFrame.new(0, 1.1, 0)
	neonTip.Parent = tool

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = neonTip
	weld.Parent = neonTip

	local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
	if humanoid and player.Team == seekersTeam then
		tool.Parent = character
	end
end

Players.PlayerAdded:Connect(function(player: Player)
	player.CharacterAdded:Connect(function(character: Model)
		task.delay(0.15, function()
			giveSeekerBatonTool(player, character)
		end)
	end)
end)
for _, p in Players:GetPlayers() do
	p.CharacterAdded:Connect(function(character: Model)
		task.delay(0.15, function()
			giveSeekerBatonTool(p, character)
		end)
	end)
end

-- Helper: Play 3D sound at position
local function play3DSound(parentPart: BasePart, soundId: string, pitch: number, volume: number)
	local s = Instance.new("Sound")
	s.SoundId = soundId
	s.PlaybackSpeed = pitch
	s.Volume = volume
	s.RollOffMaxDistance = 55
	s.Parent = parentPart
	s:Play()
	Debris:AddItem(s, 2.5)
end
-- Helper: Play a brief hit Highlight effect on the Hider or their attached prop
local function playHitHighlightEffect(hiderCharacter: Model)
	local targetAdornee = hiderCharacter:FindFirstChild("MorphedProp") or hiderCharacter

	local highlight = Instance.new("Highlight")
	highlight.Name = "SeekerHitHighlight"
	highlight.Adornee = targetAdornee
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.FillColor = Color3.fromRGB(255, 60, 60)
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	highlight.FillTransparency = 0.2
	highlight.OutlineTransparency = 0
	highlight.Parent = targetAdornee

	local fadeOut = TweenService:Create(
		highlight,
		TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ FillTransparency = 1, OutlineTransparency = 1 }
	)
	fadeOut:Play()
	Debris:AddItem(highlight, 0.55)
end

-- Handle Seeker Attack Request
seekerAttackEvent.OnServerEvent:Connect(function(seeker: Player, aimOrigin: Vector3, aimDirection: Vector3)
	if typeof(aimOrigin) ~= "Vector3" or typeof(aimDirection) ~= "Vector3" then
		return
	end

	-- 1-second server cooldown
	local now = os.clock()
	if lastAttackTime[seeker] and (now - lastAttackTime[seeker]) < ATTACK_COOLDOWN then
		return
	end

	local isSeeker, seekerChar, seekerRoot, seekerHumanoid = getValidSeeker(seeker)
	if not isSeeker or not seekerChar or not seekerRoot or not seekerHumanoid then
		return
	end

	if (aimOrigin - seekerRoot.Position).Magnitude > 25 then
		return
	end

	lastAttackTime[seeker] = now

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { seekerChar }

	local unitDir = aimDirection.Unit
	local cameraToRootDist = (aimOrigin - seekerRoot.Position).Magnitude
	local maxRayLength = cameraToRootDist + MAX_ATTACK_DISTANCE + 2

	local rayResult = workspace:Raycast(aimOrigin, unitDir * maxRayLength, rayParams)
	if not rayResult or not rayResult.Instance then
		return
	end

	local hitInstance = rayResult.Instance
	local hitPosition = rayResult.Position

	-- Validate 10-stud reach from character
	if (seekerRoot.Position - hitPosition).Magnitude > MAX_ATTACK_DISTANCE then
		return
	end

	-- Case A: Hits a Hider or their attached Prop -> 50 damage + Highlight effect
	local hiderPlayer, hiderChar, hiderHumanoid, hiderRoot = getHiderFromHit(hitInstance)
	if hiderChar and hiderHumanoid and hiderRoot then
		if hiderRoot.Anchored then
			hiderRoot.Anchored = false
			hiderHumanoid.AutoRotate = true
			hiderChar:SetAttribute("IsPropLocked", false)
		end

		local propName = tostring(hiderChar:GetAttribute("MorphedPropName") or "Prop")
		local prevHealth = hiderHumanoid.Health
		hiderHumanoid:TakeDamage(HIDER_HIT_DAMAGE)
		playHitHighlightEffect(hiderChar)
		play3DSound(hiderRoot, "rbxassetid://9119713951", 1.5, 0.9)

		local eliminated = (prevHealth > 0 and hiderHumanoid.Health <= 0)
		roundEventNotice:FireClient(seeker, "CombatFeedback", {
			Outcome = if eliminated then "Kill" else "Hit",
			Damage = HIDER_HIT_DAMAGE,
			Coins = if eliminated then SEEKER_KILL_BOUNTY_COINS else 0,
		})

		if eliminated and hiderPlayer then
			-- Award +15 Coins to Seeker and increment RoundKills
			local ls = seeker:FindFirstChild("leaderstats")
			local coins = ls and ls:FindFirstChild("Coins") :: IntValue?
			if coins then
				coins.Value += SEEKER_KILL_BOUNTY_COINS
			end
			local curKills = (seeker:GetAttribute("RoundKills") :: number?) or 0
			seeker:SetAttribute("RoundKills", curKills + 1)

			-- Progress Daily Quest for Seeker Catch
			local qCatches = (seeker:GetAttribute("Quest_CatchCount") :: number?) or 0
			qCatches += 1
			seeker:SetAttribute("Quest_CatchCount", qCatches)
			if qCatches == 1 and seeker:GetAttribute("Quest_CatchDone") ~= true then
				seeker:SetAttribute("Quest_CatchDone", true)
				if coins then
					coins.Value += 35
				end
				roundEventNotice:FireClient(seeker, "QuestComplete", {
					Title = "ภารกิจสำเร็จ: จับผู้ซ่อนสำเร็จ! (+35 Coins)",
				})
			end

			roundEventNotice:FireAllClients("KillFeed", {
				Killer = seeker.DisplayName,
				Victim = hiderPlayer.DisplayName,
				PropName = propName,
				Reason = "Eliminated",
			})
		end
		return
	end

	-- Case B: Hits a real "Morphable" object in Workspace -> Deduct 15 health from Seeker
	if isRealMorphableProp(hitInstance) then
		local prevHealth = seekerHumanoid.Health
		seekerHumanoid:TakeDamage(SEEKER_MISS_PENALTY)
		play3DSound(seekerRoot, "rbxassetid://12222124", 0.75, 0.9)

		roundEventNotice:FireClient(seeker, "CombatFeedback", {
			Outcome = "Penalty",
			Damage = SEEKER_MISS_PENALTY,
		})

		if prevHealth > 0 and seekerHumanoid.Health <= 0 then
			roundEventNotice:FireAllClients("KillFeed", {
				Killer = "Prop Penalty",
				Victim = seeker.DisplayName,
				PropName = hitInstance.Name,
				Reason = "SelfEliminated",
			})
		end
		return
	end

	-- Case C: Hits regular walls/floors -> Do nothing
end)

Players.PlayerRemoving:Connect(function(player: Player)
	lastAttackTime[player] = nil
end)
