--!strict
-- ServerScriptService/Server/PropMorph.server.luau
-- Handles:
-- 1. Hider prop morphing (unlimited prop switching during Hiding Phase & Hunting Phase!)
-- 2. Auto-Morph when Hiding Phase ends: if a Hider hasn't morphed yet when Hunting Phase begins,
--    automatically morphs them into the nearest prop!
-- 3. Prop Lock / Anchoring ([F] key) and 45-degree Prop Rotation ([R] key).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Teams = game:GetService("Teams")
local Debris = game:GetService("Debris")

local PropRemotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PropRemotes"))
local morphRequestEvent = PropRemotes.MorphRequest
local toggleLockEvent = PropRemotes.ToggleLockRequest
local rotatePropEvent = PropRemotes.RotatePropRequest
local roundEventNotice = PropRemotes.RoundEventNotice

local MAX_MORPH_DISTANCE = 35
local MORPH_TAG = "Morphable"
local HIDERS_TEAM_NAME = "Hiders"
local ACTIVE_PROP_NAME = "MorphedProp"
local COOLDOWN_TIME = 0.2

local morphCooldowns: { [Player]: number } = {}

-- Helper: Check if the player is currently an alive Hider
local function isValidHider(player: Player): (boolean, Model?, BasePart?, Humanoid?)
	local hidersTeam = Teams:FindFirstChild(HIDERS_TEAM_NAME)
	if hidersTeam and player.Team ~= hidersTeam then
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

-- Helper: Check if an instance is a valid Morphable prop (by tag OR by being inside Workspace.GameMap.Props)
local function isMorphablePropInstance(inst: Instance): boolean
	if not (inst:IsA("Model") or inst:IsA("BasePart")) then
		return false
	end
	if inst.Name == ACTIVE_PROP_NAME then
		return false
	end
	if CollectionService:HasTag(inst, MORPH_TAG) then
		return true
	end
	local parent = inst.Parent
	if parent and parent.Name == "Props" and parent.Parent and parent.Parent.Name == "GameMap" then
		return true
	end
	return false
end

-- Helper: Resolve the top-level tagged Model or BasePart
local function getMorphableTarget(instance: Instance?): Instance?
	if not instance or typeof(instance) ~= "Instance" or not instance:IsDescendantOf(workspace) then
		return nil
	end

	local current: Instance? = instance
	while current and current ~= workspace do
		if isMorphablePropInstance(current) then
			return current
		end
		current = current.Parent
	end

	return nil
end

-- Helper: Calculate distance from player's root to the target prop
local function getDistanceToProp(rootPart: BasePart, target: Instance): number
	if target:IsA("BasePart") then
		return (rootPart.Position - target.Position).Magnitude
	elseif target:IsA("Model") then
		local bboxCF, _ = target:GetBoundingBox()
		local d1 = (rootPart.Position - target:GetPivot().Position).Magnitude
		local d2 = (rootPart.Position - bboxCF.Position).Magnitude
		return math.min(d1, d2)
	end
	return math.huge
end

-- Helper: Find the closest Morphable prop in the map to a given position
local function findNearestMorphableProp(originPos: Vector3, maxRange: number?): Instance?
	local candidates: { Instance } = CollectionService:GetTagged(MORPH_TAG)
	local gameMap = workspace:FindFirstChild("GameMap")
	local propsFolder = gameMap and gameMap:FindFirstChild("Props")
	if propsFolder then
		for _, child in propsFolder:GetChildren() do
			if isMorphablePropInstance(child) then
				table.insert(candidates, child)
			end
		end
	end

	local bestProp: Instance? = nil
	local bestDist = maxRange or math.huge

	for _, prop in candidates do
		if prop:IsDescendantOf(workspace) and prop.Name ~= ACTIVE_PROP_NAME then
			local pos: Vector3? = nil
			if prop:IsA("Model") then
				pos = prop:GetPivot().Position
			elseif prop:IsA("BasePart") then
				pos = prop.Position
			end
			if pos then
				local dist = (originPos - pos).Magnitude
				if dist < bestDist then
					bestDist = dist
					bestProp = prop
				end
			end
		end
	end

	return bestProp
end

-- Helper: Hide player's character parts, decals/faces, and nametag
local function makeCharacterInvisible(character: Model, humanoid: Humanoid)
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

	local activeProp = character:FindFirstChild(ACTIVE_PROP_NAME)
	for _, desc in character:GetDescendants() do
		if activeProp and (desc == activeProp or desc:IsDescendantOf(activeProp)) then
			continue
		end

		if desc:IsA("BasePart") and desc.Name ~= "HumanoidRootPart" then
			desc.Transparency = 1
			desc.CanCollide = false
		elseif desc:IsA("Decal") or desc:IsA("Texture") then
			desc.Transparency = 1
		elseif desc:IsA("ParticleEmitter") or desc:IsA("Beam") or desc:IsA("Trail") then
			desc.Enabled = false
		end
	end
end

-- Helper: Align cloned prop with ground relative to HumanoidRootPart and weld it
local function prepareAndWeldProp(propClone: Instance, rootPart: BasePart, humanoid: Humanoid)
	local rootBottomY = rootPart.Position.Y - (rootPart.Size.Y * 0.5) - humanoid.HipHeight

	if propClone:IsA("BasePart") then
		for _, child in propClone:GetChildren() do
			if child:IsA("ProximityPrompt") or child:IsA("ClickDetector") or child:IsA("BaseScript") then
				child:Destroy()
			end
		end

		propClone.Anchored = false
		propClone.CanCollide = false
		propClone.CanQuery = true -- Enabled so Seeker raycasts can hit the disguised prop
		propClone.Massless = true

		local propHalfHeight = propClone.Size.Y * 0.5
		local targetPos = Vector3.new(rootPart.Position.X, rootBottomY + propHalfHeight, rootPart.Position.Z)
		propClone.CFrame = CFrame.new(targetPos) * rootPart.CFrame.Rotation

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = rootPart
		weld.Part1 = propClone
		weld.Parent = propClone
	elseif propClone:IsA("Model") then
		local bboxCFrame, bboxSize = propClone:GetBoundingBox()
		local pivot = propClone:GetPivot()
		local pivotToBottomOffset = pivot.Position.Y - (bboxCFrame.Position.Y - (bboxSize.Y * 0.5))

		local targetPivotPos = Vector3.new(rootPart.Position.X, rootBottomY + pivotToBottomOffset, rootPart.Position.Z)
		propClone:PivotTo(CFrame.new(targetPivotPos) * rootPart.CFrame.Rotation)

		for _, desc in propClone:GetDescendants() do
			if
				desc:IsA("ProximityPrompt")
				or desc:IsA("ClickDetector")
				or desc:IsA("BaseScript")
				or desc:IsA("JointInstance")
				or desc:IsA("WeldConstraint")
			then
				desc:Destroy()
			elseif desc:IsA("BasePart") then
				desc.Anchored = false
				desc.CanCollide = false
				desc.CanQuery = true -- Enabled so Seeker raycasts can hit the disguised prop
				desc.Massless = true

				local weld = Instance.new("WeldConstraint")
				weld.Part0 = rootPart
				weld.Part1 = desc
				weld.Parent = desc
			end
		end
	end
end

-- Helper: Apply cosmetic skin visual styling to the morphed prop
local function applyCosmeticSkinToProp(player: Player, propClone: Instance)
	local skinId = tostring(player:GetAttribute("EquippedSkin") or "Default")
	if skinId == "Default" or skinId == "" then
		return
	end

	local parts: { BasePart } = {}
	if propClone:IsA("BasePart") then
		table.insert(parts, propClone)
	else
		for _, desc in propClone:GetDescendants() do
			if desc:IsA("BasePart") then
				table.insert(parts, desc)
			end
		end
	end

	for _, p in parts do
		if skinId == "GoldProp" then
			p.Color = Color3.fromRGB(255, 200, 45)
			p.Material = Enum.Material.Metal
			p.Reflectance = 0.35
		elseif skinId == "NeonCyan" then
			p.Color = Color3.fromRGB(0, 240, 255)
			p.Material = Enum.Material.Neon
		elseif skinId == "RubySparkle" then
			p.Color = Color3.fromRGB(235, 35, 70)
			p.Material = Enum.Material.Glass
			p.Reflectance = 0.2
		elseif skinId == "GhostForceField" then
			p.Color = Color3.fromRGB(145, 210, 255)
			p.Material = Enum.Material.ForceField
		end
	end

	local primary = if propClone:IsA("BasePart")
		then propClone
		elseif propClone:IsA("Model") then (propClone.PrimaryPart or propClone:FindFirstChildWhichIsA("BasePart"))
		else nil

	if primary and (skinId == "GoldProp" or skinId == "RubySparkle") then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = if skinId == "GoldProp"
			then Color3.fromRGB(255, 235, 110)
			else Color3.fromRGB(255, 95, 130)
		sparkles.Parent = primary
	end
end

-- Helper: Calculate prop bounding box volume/height and scale Hider MaxHealth & WalkSpeed
local function applyPropSizeStats(player: Player, character: Model, humanoid: Humanoid, propClone: Instance)
	local sizeVec = Vector3.new(4, 4, 4)
	if propClone:IsA("BasePart") then
		sizeVec = propClone.Size
	elseif propClone:IsA("Model") then
		local _, bboxSize = propClone:GetBoundingBox()
		sizeVec = bboxSize
	end

	local maxDim = math.max(sizeVec.X, sizeVec.Y, sizeVec.Z)
	local baseMaxHp = 100
	local speedOffset = 0
	local sizeLabel = "Medium"

	if maxDim <= 3.6 then
		-- Small prop (e.g. TrafficCone, PlantPot, TrashBin): Harder to spot, lower HP, slightly faster
		baseMaxHp = 70
		speedOffset = 2
		sizeLabel = "Small"
	elseif maxDim >= 7.5 then
		-- Large prop (e.g. PineTree, CampingTent, Bookshelf, VendingMachine): Easy to spot, higher HP
		baseMaxHp = 140
		speedOffset = -1
		sizeLabel = "Large"
	end

	if player:GetAttribute("HasHealthPerk") == true then
		baseMaxHp += 50
	end

	local prevRatio = if humanoid.MaxHealth > 0 then math.clamp(humanoid.Health / humanoid.MaxHealth, 0.1, 1) else 1
	humanoid.MaxHealth = baseMaxHp
	humanoid.Health = math.max(15, math.round(baseMaxHp * prevRatio))

	local perkBaseSpeed = if player:GetAttribute("HasSpeedPerk") == true then 20 else 16
	local targetSpeed = math.max(12, perkBaseSpeed + speedOffset)
	character:SetAttribute("BaseWalkSpeed", targetSpeed)
	character:SetAttribute("PropSizeClass", sizeLabel)

	if humanoid.WalkSpeed > 0 and humanoid.WalkSpeed < 24 then
		humanoid.WalkSpeed = targetSpeed
	end
end

-- Helper: Play a 3D Morph Poof sound & brief particle burst on morph
local function playMorphFeedback(rootPart: BasePart)
	local sound = Instance.new("Sound")
	sound.Name = "MorphPoofSound"
	sound.SoundId = "rbxassetid://12222124"
	sound.PlaybackSpeed = 1.35
	sound.Volume = 0.65
	sound.RollOffMaxDistance = 45
	sound.Parent = rootPart
	sound:Play()
	Debris:AddItem(sound, 2)
end

-- Helper: Progress Daily Quest for Morphing
local function incrementMorphQuest(player: Player)
	local qMorphs = (player:GetAttribute("Quest_MorphCount") :: number?) or 0
	qMorphs += 1
	player:SetAttribute("Quest_MorphCount", qMorphs)
	if qMorphs == 5 and player:GetAttribute("Quest_MorphDone") ~= true then
		player:SetAttribute("Quest_MorphDone", true)
		local ls = player:FindFirstChild("leaderstats")
		local coins = ls and ls:FindFirstChild("Coins") :: IntValue?
		if coins then
			coins.Value += 25
		end
		roundEventNotice:FireClient(player, "QuestComplete", {
			Title = "ภารกิจสำเร็จ: แปลงร่างครบ 5 ครั้ง! (+25 Coins)",
		})
	end
end

-- Core Morph Execution Function (supports switching props repeatedly AND auto-morphing!)
local function morphHiderIntoTarget(player: Player, morphTarget: Instance): boolean
	local isHider, character, rootPart, humanoid = isValidHider(player)
	if not isHider or not character or not rootPart or not humanoid then
		return false
	end

	local existingProp = character:FindFirstChild(ACTIVE_PROP_NAME)
	if existingProp then
		existingProp:Destroy()
	end

	local wasAnchored = rootPart.Anchored
	rootPart.Anchored = false

	makeCharacterInvisible(character, humanoid)

	local propClone = morphTarget:Clone()
	propClone.Name = ACTIVE_PROP_NAME
	CollectionService:RemoveTag(propClone, MORPH_TAG)

	-- Save clean template name before applying skin so Decoys can strip skin if needed
	applyCosmeticSkinToProp(player, propClone)
	prepareAndWeldProp(propClone, rootPart, humanoid)
	propClone.Parent = character

	applyPropSizeStats(player, character, humanoid, propClone)
	playMorphFeedback(rootPart)
	incrementMorphQuest(player)

	local cleanPropName = string.gsub(morphTarget.Name, "_Bonus_%d+$", "")
	cleanPropName = string.gsub(cleanPropName, "_%d+$", "")
	character:SetAttribute("IsMorphed", true)
	character:SetAttribute("MorphedPropName", cleanPropName)

	rootPart.Anchored = wasAnchored
	return true
end

-- Handle Morph Requests (Hiders can change props repeatedly anytime!)
morphRequestEvent.OnServerEvent:Connect(function(player: Player, targetInstance: Instance?)
	local now = os.clock()
	if morphCooldowns[player] and (now - morphCooldowns[player]) < COOLDOWN_TIME then
		return
	end
	morphCooldowns[player] = now

	local isHider, _character, rootPart, _humanoid = isValidHider(player)
	if not isHider or not rootPart then
		return
	end

	local morphTarget = getMorphableTarget(targetInstance)
	if not morphTarget or getDistanceToProp(rootPart, morphTarget) > MAX_MORPH_DISTANCE then
		-- Fallback: if the player pressed [E] without aiming directly at a prop, morph into the nearest prop within range!
		morphTarget = findNearestMorphableProp(rootPart.Position, MAX_MORPH_DISTANCE)
	end

	if not morphTarget then
		return
	end

	morphHiderIntoTarget(player, morphTarget)
end)

-- AUTO-MORPH AT END OF HIDING PHASE:
-- When RoundState transitions to "HuntingPhase", any Hider who hasn't morphed yet
-- is automatically morphed into the closest prop to their position!
local function autoMorphUnmorphedHiders()
	local hidersTeam = Teams:FindFirstChild(HIDERS_TEAM_NAME)
	for _, player in Players:GetPlayers() do
		if not hidersTeam or player.Team == hidersTeam then
			local isHider, character, rootPart, _humanoid = isValidHider(player)
			if isHider and character and rootPart and not character:FindFirstChild(ACTIVE_PROP_NAME) then
				local nearestProp = findNearestMorphableProp(rootPart.Position)
				if nearestProp then
					morphHiderIntoTarget(player, nearestProp)
				end
			end
		end
	end
end

workspace:GetAttributeChangedSignal("RoundState"):Connect(function()
	local newState = workspace:GetAttribute("RoundState")
	if newState == "HuntingPhase" then
		autoMorphUnmorphedHiders()
		task.delay(0.3, autoMorphUnmorphedHiders)
	end
end)

-- Handle Prop Lock / Anchor Toggle
toggleLockEvent.OnServerEvent:Connect(function(player: Player)
	local isHider, character, rootPart, humanoid = isValidHider(player)
	if not isHider or not character or not rootPart or not humanoid then
		return
	end

	local newLockedState = not rootPart.Anchored
	rootPart.Anchored = newLockedState
	humanoid.AutoRotate = not newLockedState

	if newLockedState then
		rootPart.AssemblyLinearVelocity = Vector3.zero
		rootPart.AssemblyAngularVelocity = Vector3.zero
	end

	character:SetAttribute("IsPropLocked", newLockedState)
end)

-- Handle 45-Degree Prop Rotation (R key)
rotatePropEvent.OnServerEvent:Connect(function(player: Player)
	local isHider, character, rootPart, _humanoid = isValidHider(player)
	if not isHider or not character or not rootPart then
		return
	end

	if not character:FindFirstChild(ACTIVE_PROP_NAME) then
		return
	end

	local pos = rootPart.Position
	local _, currentY, _ = rootPart.CFrame:ToOrientation()
	local snappedDeg = math.round(math.deg(currentY) / 45) * 45 + 45
	rootPart.CFrame = CFrame.new(pos) * CFrame.Angles(0, math.rad(snappedDeg), 0)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	morphCooldowns[player] = nil
end)
