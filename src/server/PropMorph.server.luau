--!strict
-- ServerScriptService/Server/PropMorph.server.luau
-- Handles Hider prop morphing, prop lock/anchoring, and 45-degree prop rotation on the Server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Teams = game:GetService("Teams")

local PropRemotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PropRemotes"))
local morphRequestEvent = PropRemotes.MorphRequest
local toggleLockEvent = PropRemotes.ToggleLockRequest
local rotatePropEvent = PropRemotes.RotatePropRequest

local MAX_MORPH_DISTANCE = 15
local MORPH_TAG = "Morphable"
local HIDERS_TEAM_NAME = "Hiders"
local ACTIVE_PROP_NAME = "MorphedProp"
local COOLDOWN_TIME = 0.5

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

-- Helper: Resolve the top-level tagged Model or BasePart
local function getMorphableTarget(instance: Instance): Instance?
	if not instance or not instance:IsDescendantOf(workspace) then
		return nil
	end

	local current: Instance? = instance
	while current and current ~= workspace do
		if CollectionService:HasTag(current, MORPH_TAG) then
			if current:IsA("Model") or current:IsA("BasePart") then
				return current
			end
		end
		current = current.Parent
	end

	return nil
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

-- Helper: Calculate distance from player's root to the target prop
local function getDistanceToProp(rootPart: BasePart, target: Instance): number
	if target:IsA("BasePart") then
		return (rootPart.Position - target.Position).Magnitude
	elseif target:IsA("Model") then
		return (rootPart.Position - target:GetPivot().Position).Magnitude
	end
	return math.huge
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

-- Handle Morph Requests
morphRequestEvent.OnServerEvent:Connect(function(player: Player, targetInstance: Instance)
	local now = os.clock()
	if morphCooldowns[player] and (now - morphCooldowns[player]) < COOLDOWN_TIME then
		return
	end
	morphCooldowns[player] = now

	local isHider, character, rootPart, humanoid = isValidHider(player)
	if not isHider or not character or not rootPart or not humanoid then
		return
	end

	if typeof(targetInstance) ~= "Instance" then
		return
	end

	local morphTarget = getMorphableTarget(targetInstance)
	if not morphTarget or morphTarget.Name == ACTIVE_PROP_NAME then
		return
	end

	if getDistanceToProp(rootPart, morphTarget) > MAX_MORPH_DISTANCE then
		return
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

	prepareAndWeldProp(propClone, rootPart, humanoid)
	propClone.Parent = character

	rootPart.Anchored = wasAnchored
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

	-- Snap/rotate HumanoidRootPart by 45 degrees on the Y axis so the welded prop rotates cleanly
	local pos = rootPart.Position
	local _, currentY, _ = rootPart.CFrame:ToOrientation()
	local snappedDeg = math.round(math.deg(currentY) / 45) * 45 + 45
	rootPart.CFrame = CFrame.new(pos) * CFrame.Angles(0, math.rad(snappedDeg), 0)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	morphCooldowns[player] = nil
end)
