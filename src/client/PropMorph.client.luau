--!strict
-- StarterPlayerScripts/Client/PropMorph.client.luau
-- Client-side prop targeting, hover highlight, E/Click morph request, F/Mobile Lock button, and R/Mobile Rotate button.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Teams = game:GetService("Teams")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera

local PropRemotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PropRemotes"))
local morphRequestEvent = PropRemotes.MorphRequest
local toggleLockEvent = PropRemotes.ToggleLockRequest
local rotatePropEvent = PropRemotes.RotatePropRequest

local MAX_MORPH_DISTANCE = 15
local MORPH_TAG = "Morphable"
local HIDERS_TEAM_NAME = "Hiders"

-- Reusable Highlight for hovered Morphable objects
local hoverHighlight = Instance.new("Highlight")
hoverHighlight.Name = "MorphHoverHighlight"
hoverHighlight.FillTransparency = 0.75
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

local function getMorphableFromHit(hitInstance: Instance?): Instance?
	if not hitInstance then
		return nil
	end

	local current: Instance? = hitInstance
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

local function getTargetUnderCursor(): Instance?
	if not isLocalPlayerHider() then
		return nil
	end

	local character = localPlayer.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not character or not rootPart then
		return nil
	end

	local mouseLocation = UserInputService:GetMouseLocation()
	local viewportRay = camera:ViewportPointToRay(mouseLocation.X, mouseLocation.Y)

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { character }

	local result = workspace:Raycast(viewportRay.Origin, viewportRay.Direction * 100, rayParams)
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

	if (rootPart.Position - targetPos).Magnitude > MAX_MORPH_DISTANCE then
		return nil
	end

	return morphTarget
end

RunService.RenderStepped:Connect(function()
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

	if currentHoveredTarget then
		morphRequestEvent:FireServer(currentHoveredTarget)
		return Enum.ContextActionResult.Sink
	end

	return Enum.ContextActionResult.Pass
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
	if gameProcessed then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		local target = getTargetUnderCursor()
		if target then
			morphRequestEvent:FireServer(target)
		end
	end
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, playerWhoTriggered: Player)
	if playerWhoTriggered ~= localPlayer then
		return
	end

	local morphTarget = getMorphableFromHit(prompt.Parent)
	if morphTarget then
		morphRequestEvent:FireServer(morphTarget)
	end
end)

ContextActionService:BindAction("MorphIntoProp", handleMorphAction, false, Enum.KeyCode.E)
ContextActionService:BindAction("TogglePropLock", handleLockAction, true, Enum.KeyCode.F)
ContextActionService:SetTitle("TogglePropLock", "Lock Prop")
ContextActionService:SetPosition("TogglePropLock", UDim2.new(0.72, 0, 0.25, 0))

ContextActionService:BindAction("RotateProp", handleRotateAction, true, Enum.KeyCode.R)
ContextActionService:SetTitle("RotateProp", "Rotate 45°")
ContextActionService:SetPosition("RotateProp", UDim2.new(0.84, 0, 0.25, 0))
