--!strict
-- StarterPlayerScripts/Client/PropMorph.client.luau
-- Client-side prop targeting, hover/proximity highlight, E/Click/Touch/ProximityPrompt morph request,
-- F/Mobile Lock button, and R/Mobile Rotate button.
-- Supports switching props as many times as desired!

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Teams = game:GetService("Teams")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer

local PropRemotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PropRemotes"))
local morphRequestEvent = PropRemotes.MorphRequest
local toggleLockEvent = PropRemotes.ToggleLockRequest
local rotatePropEvent = PropRemotes.RotatePropRequest

local MAX_MORPH_DISTANCE = 32
local NEARBY_FALLBACK_DISTANCE = 20
local MORPH_TAG = "Morphable"
local HIDERS_TEAM_NAME = "Hiders"

-- Reusable Highlight for hovered or nearest Morphable objects
local hoverHighlight = Instance.new("Highlight")
hoverHighlight.Name = "MorphHoverHighlight"
hoverHighlight.FillTransparency = 0.72
hoverHighlight.OutlineTransparency = 0
hoverHighlight.FillColor = Color3.fromRGB(80, 255, 120)
hoverHighlight.OutlineColor = Color3.fromRGB(255, 255, 255)
hoverHighlight.Enabled = false
hoverHighlight.Parent = localPlayer:WaitForChild("PlayerGui")

local currentHoveredTarget: Instance? = nil

local function isLocalPlayerHider(): boolean
	local hidersTeam = Teams:FindFirstChild(HIDERS_TEAM_NAME)
	if hidersTeam and localPlayer.Team ~= hidersTeam then
		return false
	end
	return true
end

local function isMorphablePropInstance(inst: Instance): boolean
	if not (inst:IsA("Model") or inst:IsA("BasePart")) then
		return false
	end
	if inst.Name == "MorphedProp" then
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

local function getMorphableFromHit(hitInstance: Instance?): Instance?
	if not hitInstance then
		return nil
	end

	local current: Instance? = hitInstance
	while current and current ~= workspace do
		if isMorphablePropInstance(current) then
			return current
		end
		current = current.Parent
	end

	return nil
end

local function getNearestMorphableProp(rootPos: Vector3, maxDist: number): Instance?
	local bestProp: Instance? = nil
	local bestDist = maxDist

	local gameMap = workspace:FindFirstChild("GameMap")
	local propsFolder = gameMap and gameMap:FindFirstChild("Props")
	local list: { Instance } = if propsFolder then propsFolder:GetChildren() else CollectionService:GetTagged(MORPH_TAG)

	for _, prop in list do
		if isMorphablePropInstance(prop) then
			local pos = if prop:IsA("Model") then prop:GetPivot().Position else (prop :: BasePart).Position
			local d = (rootPos - pos).Magnitude
			if d < bestDist then
				bestDist = d
				bestProp = prop
			end
		end
	end

	return bestProp
end

local function getTargetFromScreenPos(screenPos: Vector2, useScreenPoint: boolean?): Instance?
	if not isLocalPlayerHider() then
		return nil
	end

	local camera = workspace.CurrentCamera
	local character = localPlayer.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not camera or not character or not rootPart then
		return nil
	end

	local ray = if useScreenPoint
		then camera:ScreenPointToRay(screenPos.X, screenPos.Y)
		else camera:ViewportPointToRay(screenPos.X, screenPos.Y)

	local ignoreList: { Instance } = { character }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(ignoreList, p.Character)
		end
	end

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = ignoreList

	local result = workspace:Raycast(ray.Origin, ray.Direction * 140, rayParams)
	if not result or not result.Instance then
		return nil
	end

	local morphTarget = getMorphableFromHit(result.Instance)
	if not morphTarget then
		return nil
	end

	local targetPos = if morphTarget:IsA("Model")
		then morphTarget:GetPivot().Position
		else (morphTarget :: BasePart).Position

	local distToHit = (rootPart.Position - result.Position).Magnitude
	local distToPivot = (rootPart.Position - targetPos).Magnitude
	if math.min(distToHit, distToPivot) > MAX_MORPH_DISTANCE then
		return nil
	end

	return morphTarget
end

local function getTargetUnderCursor(): Instance?
	local mouseLocation = UserInputService:GetMouseLocation()
	local target = getTargetFromScreenPos(mouseLocation, false)
	if target then
		return target
	end

	-- Fallback: if mouse cursor isn't directly on a prop, highlight the nearest prop within 16 studs!
	if isLocalPlayerHider() then
		local character = localPlayer.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if rootPart then
			return getNearestMorphableProp(rootPart.Position, 16)
		end
	end

	return nil
end

RunService.RenderStepped:Connect(function()
	local isHider = isLocalPlayerHider()
	ProximityPromptService.Enabled = isHider

	if not isHider then
		currentHoveredTarget = nil
		hoverHighlight.Adornee = nil
		hoverHighlight.Enabled = false
		return
	end

	local target = getTargetUnderCursor()
	currentHoveredTarget = target

	if target then
		hoverHighlight.Adornee = target
		hoverHighlight.Enabled = true
	else
		hoverHighlight.Adornee = nil
		hoverHighlight.Enabled = false
	end
end)

local function handleMorphAction(_actionName: string, inputState: Enum.UserInputState, _inputObject: InputObject)
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end

	if not isLocalPlayerHider() then
		return Enum.ContextActionResult.Pass
	end

	local target = currentHoveredTarget
	if not target then
		local character = localPlayer.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if rootPart then
			target = getNearestMorphableProp(rootPart.Position, NEARBY_FALLBACK_DISTANCE)
		end
	end

	morphRequestEvent:FireServer(target)
	return Enum.ContextActionResult.Sink
end

local function handleLockAction(_actionName: string, inputState: Enum.UserInputState, _inputObject: InputObject)
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end

	if not isLocalPlayerHider() then
		return Enum.ContextActionResult.Pass
	end

	toggleLockEvent:FireServer()
	return Enum.ContextActionResult.Sink
end

local function handleRotateAction(_actionName: string, inputState: Enum.UserInputState, _inputObject: InputObject)
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end

	if not isLocalPlayerHider() then
		return Enum.ContextActionResult.Pass
	end

	rotatePropEvent:FireServer()
	return Enum.ContextActionResult.Sink
end

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed or not isLocalPlayerHider() then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		local target = getTargetFromScreenPos(UserInputService:GetMouseLocation(), false)
		if target then
			morphRequestEvent:FireServer(target)
		end
	elseif input.UserInputType == Enum.UserInputType.Touch then
		local touchPos = Vector2.new(input.Position.X, input.Position.Y)
		local target = getTargetFromScreenPos(touchPos, true)
		if target then
			morphRequestEvent:FireServer(target)
		end
	end
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, playerWhoTriggered: Player)
	if playerWhoTriggered ~= localPlayer or not isLocalPlayerHider() then
		return
	end

	local morphTarget = getMorphableFromHit(prompt.Parent)
	if morphTarget then
		morphRequestEvent:FireServer(morphTarget)
	end
end)

ContextActionService:BindAction("MorphIntoProp", handleMorphAction, true, Enum.KeyCode.E)
ContextActionService:SetTitle("MorphIntoProp", "Morph")
ContextActionService:SetPosition("MorphIntoProp", UDim2.new(0.60, 0, 0.25, 0))

ContextActionService:BindAction("TogglePropLock", handleLockAction, true, Enum.KeyCode.F)
ContextActionService:SetTitle("TogglePropLock", "Lock Prop")
ContextActionService:SetPosition("TogglePropLock", UDim2.new(0.72, 0, 0.25, 0))

ContextActionService:BindAction("RotateProp", handleRotateAction, true, Enum.KeyCode.R)
ContextActionService:SetTitle("RotateProp", "Rotate 45°")
ContextActionService:SetPosition("RotateProp", UDim2.new(0.84, 0, 0.25, 0))
