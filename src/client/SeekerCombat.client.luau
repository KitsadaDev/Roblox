--!strict
-- StarterPlayerScripts/Client/SeekerCombat.client.luau
-- Handles Seeker raycast attacks (Left Click, Mobile Tap, or Tool Activation up to 10 studs).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Teams = game:GetService("Teams")

local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera

local PropRemotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PropRemotes"))
local seekerAttackEvent = PropRemotes.SeekerAttackRequest

local MAX_ATTACK_DISTANCE = 10
local ATTACK_COOLDOWN = 1.0
local SEEKERS_TEAM_NAME = "Seekers"

local lastClientAttack = 0

local function canLocalPlayerAttack(): (boolean, Model?, BasePart?)
	local seekersTeam = Teams:FindFirstChild(SEEKERS_TEAM_NAME)
	if seekersTeam and localPlayer.Team ~= seekersTeam then
		return false, nil, nil
	end

	local character = localPlayer.Character
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

local function performAttackRaycast()
	local now = os.clock()
	if (now - lastClientAttack) < ATTACK_COOLDOWN then
		return
	end

	local canAttack, character, rootPart = canLocalPlayerAttack()
	if not canAttack or not character or not rootPart then
		return
	end

	local mousePos = UserInputService:GetMouseLocation()
	local viewportRay = camera:ViewportPointToRay(mousePos.X, mousePos.Y)

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { character }

	local cameraDistToCharacter = (viewportRay.Origin - rootPart.Position).Magnitude
	local maxRayLength = cameraDistToCharacter + MAX_ATTACK_DISTANCE + 2

	local result = workspace:Raycast(viewportRay.Origin, viewportRay.Direction * maxRayLength, rayParams)
	if not result or not result.Instance then
		return
	end

	if (rootPart.Position - result.Position).Magnitude > MAX_ATTACK_DISTANCE then
		return
	end

	lastClientAttack = now
	seekerAttackEvent:FireServer(viewportRay.Origin, viewportRay.Direction)
end

-- 1. Attack via Left Mouse Click or Mobile Tap
UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end

	local character = localPlayer.Character
	if character and character:FindFirstChildOfClass("Tool") then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		performAttackRaycast()
	end
end)

-- 2. Attack via Equipped Tool Activation
local function bindCharacterTools(character: Model)
	character.ChildAdded:Connect(function(child: Instance)
		if child:IsA("Tool") then
			child.Activated:Connect(function()
				performAttackRaycast()
			end)
		end
	end)
end

if localPlayer.Character then
	bindCharacterTools(localPlayer.Character)
end
localPlayer.CharacterAdded:Connect(bindCharacterTools)
