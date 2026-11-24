--!strict
-- StarterPlayerScripts/Client/SeekerCombat.client.luau
-- Handles Seeker ranged gun shooting (Left Click, Mobile Tap, or SeekerBlaster Tool Activation up to 140 studs)
-- + Crosshair UI, Gun Recoil, Bullet Tracer Beams, Muzzle Flash & Impact Sparks!

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

local ATTACK_COOLDOWN = 0.55
local SEEKERS_TEAM_NAME = "Seekers"
local GUN_TOOL_NAME = "SeekerBlaster"

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

-- Tactical Center Crosshair (visible when player is on Seekers team)
local crosshairFrame = Instance.new("Frame")
crosshairFrame.Name = "SeekerCrosshair"
crosshairFrame.Size = UDim2.fromOffset(32, 32)
crosshairFrame.Position = UDim2.fromScale(0.5, 0.5)
crosshairFrame.AnchorPoint = Vector2.new(0.5, 0.5)
crosshairFrame.BackgroundTransparency = 1
crosshairFrame.Visible = false
crosshairFrame.ZIndex = 16
crosshairFrame.Parent = combatGui

local crosshairParts: { Frame } = {}
for _, spec in {
	{ Size = UDim2.fromOffset(4, 4), Pos = UDim2.fromScale(0.5, 0.5), Col = Color3.fromRGB(255, 255, 255) },
	{ Size = UDim2.fromOffset(2, 8), Pos = UDim2.new(0.5, 0, 0.5, -10), Col = Color3.fromRGB(255, 90, 95) },
	{ Size = UDim2.fromOffset(2, 8), Pos = UDim2.new(0.5, 0, 0.5, 10), Col = Color3.fromRGB(255, 90, 95) },
	{ Size = UDim2.fromOffset(8, 2), Pos = UDim2.new(0.5, -10, 0.5, 0), Col = Color3.fromRGB(255, 90, 95) },
	{ Size = UDim2.fromOffset(8, 2), Pos = UDim2.new(0.5, 10, 0.5, 0), Col = Color3.fromRGB(255, 90, 95) },
} do
	local tickBar = Instance.new("Frame")
	tickBar.Size = spec.Size
	tickBar.Position = spec.Pos
	tickBar.AnchorPoint = Vector2.new(0.5, 0.5)
	tickBar.BackgroundColor3 = spec.Col
	tickBar.BorderSizePixel = 0
	tickBar.ZIndex = 17
	tickBar.Parent = crosshairFrame

	local tickStroke = Instance.new("UIStroke")
	tickStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	tickStroke.Color = Color3.fromRGB(12, 15, 24)
	tickStroke.Thickness = 1
	tickStroke.Transparency = 0.2
	tickStroke.Parent = tickBar

	table.insert(crosshairParts, tickBar)
end

local function updateCrosshairVisibility()
	local isSeeker = localPlayer.Team ~= nil and localPlayer.Team.Name == SEEKERS_TEAM_NAME
	local isBlind = localPlayer:GetAttribute("IsBlindfolded") == true or workspace:GetAttribute("RoundState") == "HidingPhase"
	crosshairFrame.Visible = isSeeker and not isBlind
end
localPlayer:GetPropertyChangedSignal("Team"):Connect(updateCrosshairVisibility)
localPlayer:GetAttributeChangedSignal("IsBlindfolded"):Connect(updateCrosshairVisibility)
workspace:GetAttributeChangedSignal("RoundState"):Connect(updateCrosshairVisibility)
updateCrosshairVisibility()

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

-- Renders glowing bullet tracer beam, muzzle flash, impact spark, and 3D gunshot sound for all players
local function renderGunShotVfx(origin: Vector3, hitPos: Vector3, hitType: string)
	local dist = (hitPos - origin).Magnitude
	if dist < 0.2 then
		return
	end

	local tracerCol = if hitType == "Hider"
		then Color3.fromRGB(255, 225, 70)
		elseif hitType == "Penalty" then Color3.fromRGB(255, 65, 65)
		else Color3.fromRGB(255, 130, 65)

	-- Glowing Bullet Tracer Beam
	local tracer = Instance.new("Part")
	tracer.Name = "BulletTracer"
	tracer.Anchored = true
	tracer.CanCollide = false
	tracer.CanQuery = false
	tracer.CastShadow = false
	tracer.Material = Enum.Material.Neon
	tracer.Color = tracerCol
	tracer.Size = Vector3.new(0.14, 0.14, dist)
	tracer.CFrame = CFrame.lookAt(origin, hitPos) * CFrame.new(0, 0, -dist * 0.5)
	tracer.Parent = workspace

	TweenService:Create(tracer, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 1,
		Size = Vector3.new(0.03, 0.03, dist),
	}):Play()
	Debris:AddItem(tracer, 0.16)

	-- Muzzle Flash Sphere + Brief PointLight + 3D Gunshot Sound
	local flash = Instance.new("Part")
	flash.Name = "MuzzleFlash"
	flash.Shape = Enum.PartType.Ball
	flash.Anchored = true
	flash.CanCollide = false
	flash.CanQuery = false
	flash.CastShadow = false
	flash.Material = Enum.Material.Neon
	flash.Color = Color3.fromRGB(255, 215, 110)
	flash.Size = Vector3.new(0.75, 0.75, 0.75)
	flash.Position = origin
	flash.Parent = workspace

	local flashLight = Instance.new("PointLight")
	flashLight.Color = Color3.fromRGB(255, 185, 75)
	flashLight.Brightness = 2.2
	flashLight.Range = 16
	flashLight.Parent = flash

	local shotSound = Instance.new("Sound")
	shotSound.SoundId = "rbxassetid://131072992"
	shotSound.PlaybackSpeed = 1.25
	shotSound.Volume = 0.65
	shotSound.RollOffMaxDistance = 85
	shotSound.Parent = flash
	shotSound:Play()

	TweenService:Create(flash, TweenInfo.new(0.09), { Transparency = 1, Size = Vector3.new(0.1, 0.1, 0.1) }):Play()
	Debris:AddItem(flash, 0.6)

	-- Impact Spark Burst at Hit Position
	local impact = Instance.new("Part")
	impact.Name = "BulletImpact"
	impact.Shape = Enum.PartType.Ball
	impact.Anchored = true
	impact.CanCollide = false
	impact.CanQuery = false
	impact.CastShadow = false
	impact.Material = Enum.Material.Neon
	impact.Color = tracerCol
	impact.Size = Vector3.new(0.6, 0.6, 0.6)
	impact.Position = hitPos
	impact.Parent = workspace

	TweenService:Create(impact, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 1,
		Size = Vector3.new(1.8, 1.8, 1.8),
	}):Play()
	Debris:AddItem(impact, 0.2)
end

roundEventNotice.OnClientEvent:Connect(function(eventType: string, payload: { [string]: any }?)
	if eventType == "CombatFeedback" and typeof(payload) == "table" then
		local outcome = tostring(payload.Outcome or "")
		if outcome == "Kill" then
			showCombatPopup("🎯 ยิงจับได้สำเร็จ! (+15 Coins)", Color3.fromRGB(95, 255, 130), false)
		elseif outcome == "Hit" then
			local dmg = tonumber(payload.Damage) or 50
			showCombatPopup(string.format("💥 ยิงโดนผู้ซ่อน! (-%d HP)", dmg), Color3.fromRGB(255, 215, 70), false)
		elseif outcome == "Penalty" then
			showCombatPopup("❌ ยิงพลาดโดนของจริง! (-15 HP)", Color3.fromRGB(255, 75, 75), true)
		end
	elseif eventType == "GunShot" and typeof(payload) == "table" then
		local origin = payload.Origin
		local hitPos = payload.HitPos
		local hitType = tostring(payload.HitType or "Miss")
		if typeof(origin) == "Vector3" and typeof(hitPos) == "Vector3" then
			renderGunShotVfx(origin, hitPos, hitType)
		end
	end
end)

local function playLocalRecoilEffect(character: Model)
	-- Pulse crosshair size slightly on shot
	crosshairFrame.Size = UDim2.fromOffset(44, 44)
	TweenService:Create(crosshairFrame, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(32, 32),
	}):Play()

	local tool = character:FindFirstChild(GUN_TOOL_NAME)
	local handle = tool and tool:FindFirstChild("Handle") :: BasePart?
	if handle then
		local rightGrip = character:FindFirstChild("RightGrip", true) :: Motor6D?
		if rightGrip then
			local origC0 = rightGrip.C0
			TweenService:Create(rightGrip, TweenInfo.new(0.07), {
				C0 = origC0 * CFrame.new(0, 0, 0.22) * CFrame.Angles(math.rad(16), 0, 0),
			}):Play()
			task.delay(0.08, function()
				if rightGrip.Parent then
					TweenService:Create(rightGrip, TweenInfo.new(0.14), { C0 = origC0 }):Play()
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

local function performGunShot()
	local now = os.clock()
	if (now - lastClientAttack) < ATTACK_COOLDOWN then
		return
	end

	local canAttack, character, rootPart = canLocalPlayerAttack()
	if not canAttack or not character or not rootPart then
		return
	end

	lastClientAttack = now

	-- Face character horizontally toward the crosshair aim direction so gun barrel aligns with shot
	local camCF = camera.CFrame
	local flatLook = Vector3.new(camCF.LookVector.X, 0, camCF.LookVector.Z)
	if flatLook.Magnitude > 0.01 and not rootPart.Anchored then
		rootPart.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + flatLook.Unit)
	end

	playLocalRecoilEffect(character)

	-- Always fire dead-center through SeekerCrosshair (UDim2.fromScale(0.5, 0.5) in IgnoreGuiInset viewport space)
	local vpSize = camera.ViewportSize
	local aimRay = camera:ViewportPointToRay(vpSize.X * 0.5, vpSize.Y * 0.5)

	seekerAttackEvent:FireServer(aimRay.Origin, aimRay.Direction)
end

-- 1. Shoot via Left Mouse Click on PC (never on raw Touch screen-drag!)
local MobileActionBus = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MobileActionBus"))

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end

	local character = localPlayer.Character
	if character and character:FindFirstChildOfClass("Tool") then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		performGunShot()
	end
end)

-- 2. Shoot via Equipped SeekerBlaster Tool Activation on PC, or dedicated Mobile Fire Button on Touch!
local function syncToolManualMode(tool: Tool)
	tool.ManualActivationOnly = MobileActionBus.UseTouchControls()
end

local function bindTool(tool: Instance)
	if not tool:IsA("Tool") or tool:GetAttribute("_GunBound") then
		return
	end
	tool:SetAttribute("_GunBound", true)
	syncToolManualMode(tool)
	tool.Activated:Connect(function()
		if not MobileActionBus.UseTouchControls() then
			performGunShot()
		end
	end)
end

UserInputService.LastInputTypeChanged:Connect(function()
	local char = localPlayer.Character
	if char then
		for _, child in char:GetChildren() do
			if child:IsA("Tool") then
				syncToolManualMode(child)
			end
		end
	end
end)

MobileActionBus.Connect(function(action)
	if action == "SeekerShoot" then
		performGunShot()
	end
end)

local function bindCharacterTools(character: Model)
	for _, child in character:GetChildren() do
		bindTool(child)
	end
	character.ChildAdded:Connect(bindTool)
end

if localPlayer.Character then
	bindCharacterTools(localPlayer.Character)
end
localPlayer.CharacterAdded:Connect(bindCharacterTools)
