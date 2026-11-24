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
local MobileActionBus = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MobileActionBus"))
local morphRequestEvent = PropRemotes.MorphRequest
local toggleLockEvent = PropRemotes.ToggleLockRequest
local rotatePropEvent = PropRemotes.RotatePropRequest

local MAX_MORPH_DISTANCE = 32
local NEARBY_FALLBACK_DISTANCE = 20
local MORPH_TAG = "Morphable"
local HIDERS_TEAM_NAME = "Hiders"

-- Sleek Holographic Scanner Highlight & Target Prop Info Pill for Hiders
local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui

local hoverHighlight = Instance.new("Highlight")
hoverHighlight.Name = "MorphHoverHighlight"
hoverHighlight.FillTransparency = 0.82
hoverHighlight.OutlineTransparency = 0.08
hoverHighlight.FillColor = Color3.fromRGB(65, 205, 255)
hoverHighlight.OutlineColor = Color3.fromRGB(195, 242, 255)
hoverHighlight.Enabled = false
hoverHighlight.Parent = playerGui

local existingScanner = playerGui:FindFirstChild("PropScannerHudGui")
if existingScanner then
	existingScanner:Destroy()
end

local scannerGui = Instance.new("ScreenGui")
scannerGui.Name = "PropScannerHudGui"
scannerGui.ResetOnSpawn = false
scannerGui.IgnoreGuiInset = true
scannerGui.Parent = playerGui

local scannerPill = Instance.new("Frame")
scannerPill.Name = "TargetPropScannerPill"
scannerPill.Size = UDim2.fromOffset(330, 42)
scannerPill.Position = UDim2.new(0.5, 0, 1, -24)
scannerPill.AnchorPoint = Vector2.new(0.5, 1)
scannerPill.BackgroundColor3 = Color3.fromRGB(14, 19, 30)
scannerPill.BackgroundTransparency = 0.08
scannerPill.BorderSizePixel = 0
scannerPill.Visible = false
scannerPill.ZIndex = 22
scannerPill.Parent = scannerGui

local scCorner = Instance.new("UICorner")
scCorner.CornerRadius = UDim.new(0, 12)
scCorner.Parent = scannerPill

local scStroke = Instance.new("UIStroke")
scStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
scStroke.Color = Color3.fromRGB(75, 205, 255)
scStroke.Thickness = 1.5
scStroke.Transparency = 0.2
scStroke.Parent = scannerPill

local scannerLabel = Instance.new("TextLabel")
scannerLabel.Size = UDim2.new(1, -20, 1, 0)
scannerLabel.Position = UDim2.fromOffset(10, 0)
scannerLabel.BackgroundTransparency = 1
scannerLabel.Font = Enum.Font.GothamBold
scannerLabel.TextSize = 12
scannerLabel.TextTruncate = Enum.TextTruncate.AtEnd
scannerLabel.TextColor3 = Color3.fromRGB(235, 246, 255)
scannerLabel.Text = "🎯 Prop • [E / คลิก] แปลงร่าง"
scannerLabel.ZIndex = 23
scannerLabel.Parent = scannerPill

local scannerScale = Instance.new("UIScale")
scannerScale.Parent = scannerPill

local function updateScannerScale()
	scannerScale.Scale = if MobileActionBus.IsCompactPhone() then 0.78 else 1.0
end
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScannerScale)
	updateScannerScale()
end

local function describePropTarget(inst: Instance): string
	local rawName = string.gsub(inst.Name, "_Bonus_%d+$", "")
	rawName = string.gsub(rawName, "_%d+$", "")
	local spaced = string.gsub(rawName, "(%l)(%u)", "%1 %2")

	local sizeVec = Vector3.new(4, 4, 4)
	if inst:IsA("BasePart") then
		sizeVec = inst.Size
	elseif inst:IsA("Model") then
		local _, bSize = inst:GetBoundingBox()
		sizeVec = bSize
	end
	local maxDim = math.max(sizeVec.X, sizeVec.Y, sizeVec.Z)
	local hasHpPerk = localPlayer:GetAttribute("HasHealthPerk") == true
	local baseHp = if maxDim <= 3.6 then 70 elseif maxDim >= 7.5 then 140 else 100
	if hasHpPerk then
		baseHp += 50
	end
	local tierTxt = if maxDim <= 3.6 then "เล็ก" elseif maxDim >= 7.5 then "ใหญ่" else "กลาง"
	local promptHint = if MobileActionBus.UseTouchControls() then "แตะของ / กด [แปลง]" else "[E / คลิก]"
	return string.format("🎯 %s  •  ขนาด%s (%d HP)  •  %s", spaced, tierTxt, baseHp, promptHint)
end

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
	local cam = workspace.CurrentCamera
	local probePos = if MobileActionBus.UseTouchControls() and cam
		then Vector2.new(cam.ViewportSize.X * 0.5, cam.ViewportSize.Y * 0.5)
		else UserInputService:GetMouseLocation()
	local target = getTargetFromScreenPos(probePos, false)
	if target then
		return target
	end

	-- Fallback: if cursor/center isn't directly on a prop, highlight the nearest prop within 16 studs!
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
		scannerPill.Visible = false
		return
	end

	local target = getTargetUnderCursor()
	currentHoveredTarget = target

	if target then
		hoverHighlight.Adornee = target
		hoverHighlight.Enabled = true
		local char = localPlayer.Character
		local locked = char and char:GetAttribute("IsPropLocked") == true
		local isPhone = MobileActionBus.IsCompactPhone()
		local yOff = if locked
			then (if isPhone then -94 else -134)
			else (if isPhone then -12 else -24)
		scannerPill.Position = UDim2.new(0.5, 0, 1, yOff)
		scannerLabel.Text = describePropTarget(target)
		scannerPill.Visible = true
	else
		hoverHighlight.Adornee = nil
		hoverHighlight.Enabled = false
		scannerPill.Visible = false
	end
end)

local function triggerMorphIntoBestTarget()
	if not isLocalPlayerHider() then
		return
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
end

local function handleMorphAction(_actionName: string, inputState: Enum.UserInputState, _inputObject: InputObject)
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end

	if not isLocalPlayerHider() then
		return Enum.ContextActionResult.Pass
	end

	triggerMorphIntoBestTarget()
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
	end
end)

-- Mobile/Touch: only morph on intentional world tap (never when dragging finger to rotate camera!)
UserInputService.TouchTapInWorld:Connect(function(touchPos: Vector2, processedByUI: boolean)
	if processedByUI or not isLocalPlayerHider() then
		return
	end

	local target = getTargetFromScreenPos(touchPos, false) or getTargetFromScreenPos(touchPos, true)
	if target then
		morphRequestEvent:FireServer(target)
	end
end)

MobileActionBus.Connect(function(action)
	if action == "Morph" then
		triggerMorphIntoBestTarget()
	elseif action == "ToggleLock" then
		if isLocalPlayerHider() then
			toggleLockEvent:FireServer()
		end
	elseif action == "RotateProp" then
		if isLocalPlayerHider() then
			rotatePropEvent:FireServer()
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

-- Bind PC keys only (false = no overlapping default ContextActionService grey touch buttons!)
ContextActionService:BindAction("MorphIntoProp", handleMorphAction, false, Enum.KeyCode.E)
ContextActionService:BindAction("TogglePropLock", handleLockAction, false, Enum.KeyCode.F)
ContextActionService:BindAction("RotateProp", handleRotateAction, false, Enum.KeyCode.R)
ContextActionService:SetPosition("RotateProp", UDim2.new(0.84, 0, 0.25, 0))
