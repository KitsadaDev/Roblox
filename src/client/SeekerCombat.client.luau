--!strict
-- StarterPlayerScripts/Client/SeekerCombat.client.luau
-- Handles Seeker raycast attacks (Left Click, Mobile Tap, or Tool Activation up to 10 studs).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Teams = game:GetService("Teams")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera
local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui

local PropRemotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PropRemotes"))
local seekerAttackEvent = PropRemotes.SeekerAttackRequest
local roundEventNotice = PropRemotes.RoundEventNotice

local MAX_ATTACK_DISTANCE = 10
local ATTACK_COOLDOWN = 1.0
local SEEKERS_TEAM_NAME = "Seekers"

local lastClientAttack = 0

--------------------------------------------------------------------------------
-- SEEKER COMBAT UI OVERLAY (Crosshair, Hitmarker & Penalty Flash)
--------------------------------------------------------------------------------
local combatGui = Instance.new("ScreenGui")
combatGui.Name = "PropHuntSeekerCombatGui"
combatGui.ResetOnSpawn = false
combatGui.IgnoreGuiInset = true
combatGui.Parent = playerGui

local penaltyFlash = Instance.new("Frame")
penaltyFlash.Name = "PenaltyFlash"
penaltyFlash.Size = UDim2.fromScale(1, 1)
penaltyFlash.BackgroundColor3 = Color3.fromRGB(255, 45, 45)
penaltyFlash.BackgroundTransparency = 1
penaltyFlash.BorderSizePixel = 0
penaltyFlash.ZIndex = 5
penaltyFlash.Parent = combatGui

local feedbackLabel = Instance.new("TextLabel")
feedbackLabel.Name = "HitFeedbackLabel"
feedbackLabel.Size = UDim2.new(0, 260, 0, 36)
feedbackLabel.Position = UDim2.new(0.5, 0, 0.56, 0)
feedbackLabel.AnchorPoint = Vector2.new(0.5, 0.5)
feedbackLabel.BackgroundTransparency = 1
feedbackLabel.Font = Enum.Font.GothamBlack
feedbackLabel.TextSize = 20
feedbackLabel.TextStrokeTransparency = 0.25
feedbackLabel.TextTransparency = 1
feedbackLabel.Text = ""
feedbackLabel.ZIndex = 18
feedbackLabel.Parent = combatGui

local function showCombatPopup(text: string, color: Color3, flashScreenRed: boolean)
	feedbackLabel.Text = text
	feedbackLabel.TextColor3 = color
	feedbackLabel.Position = UDim2.new(0.5, 0, 0.56, 0)
	feedbackLabel.TextTransparency = 0
	feedbackLabel.TextStrokeTransparency = 0.2

	TweenService:Create(feedbackLabel, TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0.50, 0),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()

	if flashScreenRed then
		penaltyFlash.BackgroundTransparency = 0.65
		TweenService:Create(penaltyFlash, TweenInfo.new(0.45), { BackgroundTransparency = 1 }):Play()
	end
end

roundEventNotice.OnClientEvent:Connect(function(eventType: string, payload: { [string]: any }?)
	if eventType == "CombatFeedback" and typeof(payload) == "table" then
		local outcome = tostring(payload.Outcome or "")
		if outcome == "Kill" then
			showCombatPopup("🎯 จับได้สำเร็จ! (+15 Coins)", Color3.fromRGB(95, 255, 130), false)
		elseif outcome == "Hit" then
			showCombatPopup("💥 โดนผู้ซ่อน! (-50 HP)", Color3.fromRGB(255, 215, 70), false)
		elseif outcome == "Penalty" then
			showCombatPopup("❌ ตีผิดของจริง! (-15 HP)", Color3.fromRGB(255, 75, 75), true)
		end
	end
end)

local function playLocalSwingEffect(character: Model)
	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if rootPart then
		local whoosh = Instance.new("Sound")
		whoosh.SoundId = "rbxassetid://12222124"
		whoosh.PlaybackSpeed = 1.85
		whoosh.Volume = 0.45
		whoosh.Parent = rootPart
		whoosh:Play()
		Debris:AddItem(whoosh, 1.0)
	end

	local tool = character:FindFirstChild("SeekerScannerBaton")
	local handle = tool and tool:FindFirstChild("Handle") :: BasePart?
	if handle then
		local rightGrip = character:FindFirstChild("RightGrip", true) :: Motor6D?
		if rightGrip then
			local origC0 = rightGrip.C0
			TweenService:Create(rightGrip, TweenInfo.new(0.12), {
				C0 = origC0 * CFrame.Angles(math.rad(-65), 0, 0),
			}):Play()
			task.delay(0.14, function()
				if rightGrip.Parent then
					TweenService:Create(rightGrip, TweenInfo.new(0.18), { C0 = origC0 }):Play()
				end
			end)
		end
	end
end

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

	playLocalSwingEffect(character)

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
