--!strict
-- ServerScriptService/Server/SeekerCombat.server.luau
-- Handles Seeker ranged gun combat (Case A: 50 dmg + highlight to Hiders, Case B: 15 self-damage on real Morphable props, Case C: wall impact).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Teams = game:GetService("Teams")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local PropRemotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PropRemotes"))
local seekerAttackEvent = PropRemotes.SeekerAttackRequest
local roundEventNotice = PropRemotes.RoundEventNotice

-- Gun Combat Constants
local MAX_SHOOT_DISTANCE = 140 -- 140 studs ranged blaster reach
local ATTACK_COOLDOWN = 0.55 -- 0.55-second fire rate cooldown
local HIDER_HIT_DAMAGE = 50 -- Case A: Damage dealt to a Hider
local SEEKER_MISS_PENALTY = 15 -- Case B: Health penalty when shooting a real Morphable object
local SEEKER_KILL_BOUNTY_COINS = 15 -- Coins awarded to Seeker per Hider eliminated

local MORPH_TAG = "Morphable"
local SEEKERS_TEAM_NAME = "Seekers"
local HIDERS_TEAM_NAME = "Hiders"
local GUN_TOOL_NAME = "SeekerBlaster"

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

-- Helper: Remove SeekerBlaster if player leaves Seekers team
local function removeSeekerGunTool(player: Player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		local old = backpack:FindFirstChild(GUN_TOOL_NAME)
		if old then
			old:Destroy()
		end
	end
	if player.Character then
		local old = player.Character:FindFirstChild(GUN_TOOL_NAME)
		if old then
			old:Destroy()
		end
	end
end

-- Helper: Build & reliably equip the SeekerBlaster gun via Backpack + Humanoid:EquipTool()
local function giveSeekerGunTool(player: Player, character: Model?)
	local seekersTeam = Teams:FindFirstChild(SEEKERS_TEAM_NAME)
	if not seekersTeam or player.Team ~= seekersTeam then
		removeSeekerGunTool(player)
		return
	end

	local char = character or player.Character
	if not char or not char.Parent then
		return
	end

	local humanoid = char:WaitForChild("Humanoid", 5) :: Humanoid?
	local rootPart = char:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	local backpack = player:WaitForChild("Backpack", 5) :: Backpack?
	if not humanoid or not rootPart or not backpack or player.Team ~= seekersTeam then
		return
	end

	-- If player already has the gun in Backpack, just equip it
	local existingInChar = char:FindFirstChild(GUN_TOOL_NAME)
	if existingInChar and existingInChar:IsA("Tool") then
		return
	end
	local existingInBag = backpack:FindFirstChild(GUN_TOOL_NAME)
	if existingInBag and existingInBag:IsA("Tool") then
		humanoid:EquipTool(existingInBag)
		return
	end

	local tool = Instance.new("Tool")
	tool.Name = GUN_TOOL_NAME
	tool.ToolTip = "คลิกซ้าย / แตะหน้าจอ เพื่อยิงปืนไล่ล่าผู้ซ่อน!"
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.Grip = CFrame.new(0, -0.25, 0.35)

	local function gunPart(
		name: string,
		size: Vector3,
		offset: CFrame,
		color: Color3,
		material: Enum.Material,
		parentTool: Tool,
		handleRef: Part?
	): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = color
		p.Material = material
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CanCollide = false
		p.CanQuery = false
		p.Massless = true
		if handleRef then
			p.CFrame = handleRef.CFrame * offset
		else
			p.CFrame = rootPart.CFrame
		end
		p.Parent = parentTool

		if handleRef then
			local w = Instance.new("WeldConstraint")
			w.Part0 = handleRef
			w.Part1 = p
			w.Parent = p
		end
		return p
	end

	-- Grip Handle (held in right hand)
	local handle = gunPart(
		"Handle",
		Vector3.new(0.36, 1.0, 0.48),
		CFrame.identity,
		Color3.fromRGB(36, 40, 48),
		Enum.Material.Metal,
		tool,
		nil
	)

	-- Main Gun Receiver Body (extends forward along -Z)
	gunPart("Receiver", Vector3.new(0.48, 0.68, 2.35), CFrame.new(0, 0.58, -0.65), Color3.fromRGB(48, 54, 68), Enum.Material.Metal, tool, handle)
	-- Front Barrel
	gunPart("Barrel", Vector3.new(0.28, 0.28, 1.55), CFrame.new(0, 0.64, -2.35), Color3.fromRGB(28, 30, 38), Enum.Material.Metal, tool, handle)
	-- Glowing Tactical Neon Rail Strips
	gunPart("NeonRailTop", Vector3.new(0.2, 0.1, 2.0), CFrame.new(0, 0.96, -0.75), Color3.fromRGB(255, 65, 85), Enum.Material.Neon, tool, handle)
	gunPart("NeonBarrelRing", Vector3.new(0.38, 0.38, 0.2), CFrame.new(0, 0.64, -2.75), Color3.fromRGB(255, 75, 95), Enum.Material.Neon, tool, handle)
	-- Magazine & Tactical Stock
	gunPart("Magazine", Vector3.new(0.3, 0.9, 0.48), CFrame.new(0, -0.05, -0.95) * CFrame.Angles(math.rad(-14), 0, 0), Color3.fromRGB(30, 34, 42), Enum.Material.Metal, tool, handle)
	gunPart("Stock", Vector3.new(0.36, 0.58, 1.1), CFrame.new(0, 0.5, 0.95), Color3.fromRGB(38, 42, 52), Enum.Material.SmoothPlastic, tool, handle)
	-- Red-Dot Sight Scope
	gunPart("ScopeBody", Vector3.new(0.3, 0.3, 0.75), CFrame.new(0, 1.1, -0.4), Color3.fromRGB(28, 30, 36), Enum.Material.Metal, tool, handle)
	gunPart("ScopeLens", Vector3.new(0.22, 0.22, 0.08), CFrame.new(0, 1.1, -0.78), Color3.fromRGB(0, 235, 255), Enum.Material.Neon, tool, handle)
	-- Muzzle Tip (used as tracer & muzzle flash origin)
	local muzzle = gunPart("Muzzle", Vector3.new(0.24, 0.24, 0.24), CFrame.new(0, 0.64, -3.18), Color3.fromRGB(255, 195, 75), Enum.Material.Neon, tool, handle)
	muzzle.Transparency = 1

	-- Parent to Backpack first so it never falls into void, then equip onto Humanoid!
	tool.Parent = backpack
	task.wait(0.05)
	if tool.Parent == backpack and humanoid.Health > 0 and player.Team == seekersTeam then
		humanoid:EquipTool(tool)
	end
end

local function hookPlayerForSeekerGun(player: Player)
	player.CharacterAdded:Connect(function(character: Model)
		task.delay(0.25, function()
			giveSeekerGunTool(player, character)
		end)
	end)
	player:GetPropertyChangedSignal("Team"):Connect(function()
		task.delay(0.25, function()
			giveSeekerGunTool(player, player.Character)
		end)
	end)
	if player.Character then
		task.delay(0.25, function()
			giveSeekerGunTool(player, player.Character)
		end)
	end
end

Players.PlayerAdded:Connect(hookPlayerForSeekerGun)
for _, p in Players:GetPlayers() do
	hookPlayerForSeekerGun(p)
end

-- Also re-verify Seeker gun is equipped whenever HuntingPhase begins (right after Seeker unfreezes!)
workspace:GetAttributeChangedSignal("RoundState"):Connect(function()
	local state = workspace:GetAttribute("RoundState")
	if state == "HidingPhase" or state == "HuntingPhase" then
		for _, p in Players:GetPlayers() do
			if p.Team and p.Team.Name == SEEKERS_TEAM_NAME then
				task.spawn(giveSeekerGunTool, p, p.Character)
			end
		end
	end
end)

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

-- Handle Seeker Gun Shot Request
seekerAttackEvent.OnServerEvent:Connect(function(seeker: Player, aimOrigin: Vector3, aimDirection: Vector3)
	if workspace:GetAttribute("RoundState") ~= "HuntingPhase" then
		return
	end
	if typeof(aimOrigin) ~= "Vector3" or typeof(aimDirection) ~= "Vector3" then
		return
	end
	if aimDirection.Magnitude < 0.001 then
		return
	end

	-- Server fire-rate cooldown
	local now = os.clock()
	if lastAttackTime[seeker] and (now - lastAttackTime[seeker]) < ATTACK_COOLDOWN then
		return
	end

	local isSeeker, seekerChar, seekerRoot, seekerHumanoid = getValidSeeker(seeker)
	if not isSeeker or not seekerChar or not seekerRoot or not seekerHumanoid then
		return
	end

	if (aimOrigin - seekerRoot.Position).Magnitude > 30 then
		return
	end

	lastAttackTime[seeker] = now

	-- Find gun muzzle position for bullet tracer visual
	local gunTool = seekerChar:FindFirstChild(GUN_TOOL_NAME)
	local muzzlePart = gunTool and gunTool:FindFirstChild("Muzzle") :: BasePart?
	local tracerOrigin = if muzzlePart then muzzlePart.Position else (seekerRoot.Position + Vector3.new(0, 1.4, 0))

	-- Exclude the shooting Seeker and any non-Hider characters so fellow Seekers never block the crosshair ray
	local excludeList: { Instance } = { seekerChar }
	local hidersTeam = Teams:FindFirstChild(HIDERS_TEAM_NAME)
	for _, otherPlayer in Players:GetPlayers() do
		if otherPlayer ~= seeker and otherPlayer.Character then
			if not hidersTeam or otherPlayer.Team ~= hidersTeam then
				table.insert(excludeList, otherPlayer.Character)
			end
		end
	end

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = excludeList

	local unitDir = aimDirection.Unit
	-- Start the crosshair ray at the Seeker's forward plane (still 100% collinear with the crosshair!)
	-- so ceiling beams or props behind the Seeker's back never intercept the camera ray.
	local forwardStartOffset = math.max(0, (seekerRoot.Position - aimOrigin):Dot(unitDir) - 1.0)
	local rayStart = aimOrigin + unitDir * forwardStartOffset
	local aimResult = workspace:Raycast(rayStart, unitDir * MAX_SHOOT_DISTANCE, rayParams)
	local targetPoint = if aimResult then aimResult.Position else (rayStart + unitDir * MAX_SHOOT_DISTANCE)

	local hitInstance: Instance? = if aimResult then aimResult.Instance else nil
	local hitPosition: Vector3 = targetPoint

	-- Anti-wallbang check from eye level: only clamp if a solid wall genuinely blocks line-of-sight to targetPoint
	local eyeOrigin = seekerRoot.Position + Vector3.new(0, 1.8, 0)
	local toTarget = targetPoint - eyeOrigin
	if toTarget.Magnitude > 1.0 then
		local losResult = workspace:Raycast(eyeOrigin, toTarget.Unit * (toTarget.Magnitude - 0.8), rayParams)
		if losResult and (losResult.Position - targetPoint).Magnitude > 2.5 then
			local losHider = getHiderFromHit(losResult.Instance)
			local aimHider = if hitInstance then getHiderFromHit(hitInstance) else nil
			if losResult.Instance ~= hitInstance and (losHider == nil or losHider ~= aimHider) and not isRealMorphableProp(losResult.Instance) then
				hitInstance = losResult.Instance
				hitPosition = losResult.Position
			end
		end
	end

	local hitType = "Miss"

	-- Case A: Hits a Hider or their attached Prop -> 50 damage + Highlight effect
	if hitInstance then
		local hiderPlayer, hiderChar, hiderHumanoid, hiderRoot = getHiderFromHit(hitInstance)
		if hiderChar and hiderHumanoid and hiderRoot then
			hitType = "Hider"
			roundEventNotice:FireAllClients("GunShot", {
				Origin = tracerOrigin,
				HitPos = hitPosition,
				HitType = hitType,
			})

			if hiderRoot.Anchored then
				hiderRoot.Anchored = false
				hiderHumanoid.AutoRotate = true
				hiderChar:SetAttribute("IsPropLocked", false)
			end

			local propName = tostring(hiderChar:GetAttribute("MorphedPropName") or "Prop")
			local prevHealth = hiderHumanoid.Health
			-- Guaranteed 2-shot kill against any Hider (scales to 50% of MaxHealth, minimum 50 dmg)
			local damageDealt = math.max(HIDER_HIT_DAMAGE, math.ceil(hiderHumanoid.MaxHealth * 0.5))
			hiderHumanoid:TakeDamage(damageDealt)
			playHitHighlightEffect(hiderChar)
			play3DSound(hiderRoot, "rbxassetid://9119713951", 1.5, 0.9)

			local eliminated = (prevHealth > 0 and hiderHumanoid.Health <= 0)
			roundEventNotice:FireClient(seeker, "CombatFeedback", {
				Outcome = if eliminated then "Kill" else "Hit",
				Damage = damageDealt,
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
			hitType = "Penalty"
			roundEventNotice:FireAllClients("GunShot", {
				Origin = tracerOrigin,
				HitPos = hitPosition,
				HitType = hitType,
			})

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
	end

	-- Case C: Hits regular walls/floors or air -> Broadcast tracer only, no penalty
	roundEventNotice:FireAllClients("GunShot", {
		Origin = tracerOrigin,
		HitPos = hitPosition,
		HitType = hitType,
	})
end)

Players.PlayerRemoving:Connect(function(player: Player)
	lastAttackTime[player] = nil
end)
