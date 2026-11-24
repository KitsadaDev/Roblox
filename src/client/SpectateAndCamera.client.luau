--!strict
-- StarterPlayerScripts/Client/SpectateAndCamera.client.luau
-- 1. Hider Prop Camera Helper (Lifts camera offset & fades close prop parts)
-- 2. Dramatic Seeker Blindfold Countdown Screen during Hiding Phase
-- 3. Polished Glassmorphic Spectator Camera Bar (Lobby + Locked Hiders [V])

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local Teams = game:GetService("Teams")

local MobileActionBus = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MobileActionBus"))

local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera
local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui

local function addCorner(inst: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = inst
end

local function addBorderStroke(inst: Instance, col: Color3, thick: number, trans: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Color = col
	s.Thickness = thick
	s.Transparency = trans or 0.25
	s.Parent = inst
	return s
end

--------------------------------------------------------------------------------
-- CREATE SCREENGUI
--------------------------------------------------------------------------------
local existingGui = playerGui:FindFirstChild("PropHuntQoLGui")
if existingGui then
	existingGui:Destroy()
end

local qolGui = Instance.new("ScreenGui")
qolGui.Name = "PropHuntQoLGui"
qolGui.ResetOnSpawn = false
qolGui.IgnoreGuiInset = true
qolGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
qolGui.Parent = playerGui

--------------------------------------------------------------------------------
-- 1. SEEKER BLINDFOLD OVERLAY (Atmospheric Countdown Screen during Hiding Phase)
--------------------------------------------------------------------------------
local blindfoldFrame = Instance.new("Frame")
blindfoldFrame.Name = "SeekerBlindfoldFrame"
blindfoldFrame.Size = UDim2.fromScale(1, 1)
blindfoldFrame.BackgroundColor3 = Color3.fromRGB(8, 10, 16)
blindfoldFrame.BorderSizePixel = 0
blindfoldFrame.Visible = false
blindfoldFrame.ZIndex = 15
blindfoldFrame.Parent = qolGui

local bfGrad = Instance.new("UIGradient")
bfGrad.Color = ColorSequence.new(Color3.fromRGB(24, 12, 18), Color3.fromRGB(6, 8, 14))
bfGrad.Rotation = 120
bfGrad.Parent = blindfoldFrame

local bfCard = Instance.new("Frame")
bfCard.Size = UDim2.fromOffset(480, 210)
bfCard.Position = UDim2.fromScale(0.5, 0.5)
bfCard.AnchorPoint = Vector2.new(0.5, 0.5)
bfCard.BackgroundColor3 = Color3.fromRGB(18, 20, 30)
bfCard.BorderSizePixel = 0
bfCard.ZIndex = 16
bfCard.Parent = blindfoldFrame
addCorner(bfCard, 20)
addBorderStroke(bfCard, Color3.fromRGB(255, 85, 95), 2, 0.2)

local bfCardScale = Instance.new("UIScale")
bfCardScale.Parent = bfCard

local blindfoldTitle = Instance.new("TextLabel")
blindfoldTitle.Name = "BlindfoldTitle"
blindfoldTitle.Size = UDim2.new(1, -32, 0, 36)
blindfoldTitle.Position = UDim2.fromOffset(16, 26)
blindfoldTitle.BackgroundTransparency = 1
blindfoldTitle.Font = Enum.Font.GothamBlack
blindfoldTitle.TextSize = 22
blindfoldTitle.TextColor3 = Color3.fromRGB(255, 95, 105)
blindfoldTitle.Text = "🟥 คุณเป็นฝ่ายหา (SEEKER)!"
blindfoldTitle.ZIndex = 17
blindfoldTitle.Parent = bfCard

local blindfoldSub = Instance.new("TextLabel")
blindfoldSub.Size = UDim2.new(1, -32, 0, 24)
blindfoldSub.Position = UDim2.fromOffset(16, 66)
blindfoldSub.BackgroundTransparency = 1
blindfoldSub.Font = Enum.Font.GothamMedium
blindfoldSub.TextSize = 14
blindfoldSub.TextColor3 = Color3.fromRGB(195, 210, 235)
blindfoldSub.Text = "เหล่าผู้ซ่อนกำลังแปลงร่าง... เตรียมออกล่าพร้อมกัน!"
blindfoldSub.ZIndex = 17
blindfoldSub.Parent = bfCard

local blindfoldCountdown = Instance.new("TextLabel")
blindfoldCountdown.Name = "BlindfoldCountdown"
blindfoldCountdown.Size = UDim2.new(1, -64, 0, 66)
blindfoldCountdown.Position = UDim2.fromOffset(32, 114)
blindfoldCountdown.BackgroundColor3 = Color3.fromRGB(28, 18, 26)
blindfoldCountdown.Font = Enum.Font.GothamBlack
blindfoldCountdown.TextSize = 32
blindfoldCountdown.TextColor3 = Color3.fromRGB(255, 225, 90)
blindfoldCountdown.Text = "⏳ ปล่อยตัวใน 30s"
blindfoldCountdown.ZIndex = 17
blindfoldCountdown.Parent = bfCard
addCorner(blindfoldCountdown, 14)
addBorderStroke(blindfoldCountdown, Color3.fromRGB(255, 195, 70), 1.4, 0.35)

local function updateSeekerBlindfold()
	local roundState = workspace:GetAttribute("RoundState")
	local roundTimer = workspace:GetAttribute("RoundTimer")
	local seekersTeam = Teams:FindFirstChild("Seekers")

	local isSeeker = seekersTeam ~= nil and localPlayer.Team == seekersTeam
	local shouldBlind = isSeeker and (roundState == "HidingPhase" or localPlayer:GetAttribute("IsBlindfolded") == true)

	blindfoldFrame.Visible = shouldBlind

	if shouldBlind then
		local secondsLeft = if typeof(roundTimer) == "number" then math.max(0, math.ceil(roundTimer)) else 0
		blindfoldCountdown.Text = string.format("⏳ ปล่อยตัวในอีก %d วินาที", secondsLeft)

		local character = localPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.UseJumpPower = true
			humanoid.WalkSpeed = 0
			humanoid.JumpPower = 0
		end
	else
		local character = localPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.WalkSpeed == 0 then
			local defaultSpeed = if localPlayer:GetAttribute("HasSpeedPerk") == true then 20 else 16
			humanoid.WalkSpeed = defaultSpeed
			humanoid.JumpPower = 50
		end
	end
end

--------------------------------------------------------------------------------
-- 2. SPECTATOR CAMERA SYSTEM (For Lobby Players AND Locked Hiders!)
--------------------------------------------------------------------------------
local isSpectating = false
local currentTargetIndex = 1

local spectateButton = Instance.new("TextButton")
spectateButton.Name = "SpectateToggleButton"
spectateButton.Size = UDim2.fromOffset(236, 44)
spectateButton.Position = UDim2.new(0.5, 0, 1, -22)
spectateButton.AnchorPoint = Vector2.new(0.5, 1)
spectateButton.BackgroundColor3 = Color3.fromRGB(20, 26, 40)
spectateButton.AutoButtonColor = false
spectateButton.Font = Enum.Font.GothamBlack
spectateButton.TextSize = 14
spectateButton.TextColor3 = Color3.fromRGB(255, 255, 255)
spectateButton.Text = "👁️ ส่องดูเพื่อนที่ซ่อนอยู่ [V]"
spectateButton.Visible = false
spectateButton.ZIndex = 20
spectateButton.Parent = qolGui
addCorner(spectateButton, 12)
addBorderStroke(spectateButton, Color3.fromRGB(85, 195, 255), 1.6, 0.2)

local spectateBtnScale = Instance.new("UIScale")
spectateBtnScale.Parent = spectateButton

local switcherBar = Instance.new("Frame")
switcherBar.Name = "SpectatorSwitcherBar"
switcherBar.Size = UDim2.fromOffset(360, 50)
switcherBar.Position = UDim2.new(0.5, 0, 1, -76)
switcherBar.AnchorPoint = Vector2.new(0.5, 1)
switcherBar.BackgroundColor3 = Color3.fromRGB(16, 20, 32)
switcherBar.BackgroundTransparency = 0.08
switcherBar.BorderSizePixel = 0
switcherBar.Visible = false
switcherBar.ZIndex = 20
switcherBar.Parent = qolGui
addCorner(switcherBar, 14)
addBorderStroke(switcherBar, Color3.fromRGB(85, 165, 245), 1.5, 0.3)

local switcherScale = Instance.new("UIScale")
switcherScale.Parent = switcherBar

local function updateSpectateResponsive()
	local isPhone = MobileActionBus.IsCompactPhone()
	bfCardScale.Scale = if isPhone then 0.72 else 1.0
	spectateBtnScale.Scale = if isPhone then 0.78 else 1.0
	switcherScale.Scale = if isPhone then 0.78 else 1.0
	spectateButton.Position = if isPhone then UDim2.new(0.5, 0, 1, -10) else UDim2.new(0.5, 0, 1, -22)
	switcherBar.Position = if isPhone then UDim2.new(0.5, 0, 1, -50) else UDim2.new(0.5, 0, 1, -76)
end
if camera then
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateSpectateResponsive)
	updateSpectateResponsive()
end

local prevArrowBtn = Instance.new("TextButton")
prevArrowBtn.Name = "PrevButton"
prevArrowBtn.Size = UDim2.fromOffset(44, 38)
prevArrowBtn.Position = UDim2.new(0, 6, 0.5, 0)
prevArrowBtn.AnchorPoint = Vector2.new(0, 0.5)
prevArrowBtn.BackgroundColor3 = Color3.fromRGB(26, 34, 52)
prevArrowBtn.Font = Enum.Font.GothamBlack
prevArrowBtn.TextSize = 18
prevArrowBtn.TextColor3 = Color3.fromRGB(95, 195, 255)
prevArrowBtn.Text = "◀"
prevArrowBtn.ZIndex = 21
prevArrowBtn.Parent = switcherBar
addCorner(prevArrowBtn, 10)

local nextArrowBtn = Instance.new("TextButton")
nextArrowBtn.Name = "NextButton"
nextArrowBtn.Size = UDim2.fromOffset(44, 38)
nextArrowBtn.Position = UDim2.new(1, -6, 0.5, 0)
nextArrowBtn.AnchorPoint = Vector2.new(1, 0.5)
nextArrowBtn.BackgroundColor3 = Color3.fromRGB(26, 34, 52)
nextArrowBtn.Font = Enum.Font.GothamBlack
nextArrowBtn.TextSize = 18
nextArrowBtn.TextColor3 = Color3.fromRGB(95, 195, 255)
nextArrowBtn.Text = "▶"
nextArrowBtn.ZIndex = 21
nextArrowBtn.Parent = switcherBar
addCorner(nextArrowBtn, 10)

local spectatedNameLabel = Instance.new("TextLabel")
spectatedNameLabel.Name = "SpectatedNameLabel"
spectatedNameLabel.Size = UDim2.new(1, -112, 1, 0)
spectatedNameLabel.Position = UDim2.fromOffset(56, 0)
spectatedNameLabel.BackgroundTransparency = 1
spectatedNameLabel.Font = Enum.Font.GothamBold
spectatedNameLabel.TextSize = 13
spectatedNameLabel.TextColor3 = Color3.fromRGB(245, 248, 255)
spectatedNameLabel.Text = "กำลังดูเพื่อน..."
spectatedNameLabel.TextTruncate = Enum.TextTruncate.AtEnd
spectatedNameLabel.ZIndex = 21
spectatedNameLabel.Parent = switcherBar

local function isLocalPlayerLockedHider(): boolean
	local hidersTeam = Teams:FindFirstChild("Hiders")
	if not hidersTeam or localPlayer.Team ~= hidersTeam then
		return false
	end

	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 then
		return false
	end

	return character:GetAttribute("IsPropLocked") == true
end

local function getSpectatableTargets(): { Player }
	local targets: { Player } = {}
	local hidersTeam = Teams:FindFirstChild("Hiders")
	local seekersTeam = Teams:FindFirstChild("Seekers")
	local lockedHiderMode = isLocalPlayerLockedHider()
	local isRevealPhase = (workspace:GetAttribute("RoundState") == "RoundOver")

	for _, player in Players:GetPlayers() do
		if lockedHiderMode or isRevealPhase then
			if player ~= localPlayer and player.Team == hidersTeam then
				local char = player.Character
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				if hum and hum.Health > 0 then
					table.insert(targets, player)
				end
			end
		else
			if player ~= localPlayer and (player.Team == hidersTeam or player.Team == seekersTeam) then
				local char = player.Character
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				if hum and hum.Health > 0 then
					table.insert(targets, player)
				end
			end
		end
	end

	return targets
end

local function getDefaultButtonLabel(): string
	local useTouch = MobileActionBus.UseTouchControls()
	if isLocalPlayerLockedHider() then
		return if useTouch then "👁️ ส่องดูเพื่อนที่ซ่อนอยู่" else "👁️ ส่องดูเพื่อนที่ซ่อนอยู่ [V]"
	else
		return "🎥 ดูการแข่งขันสด (Spectate)"
	end
end

local function getActiveStopSpectateLabel(): string
	local useTouch = MobileActionBus.UseTouchControls()
	if isLocalPlayerLockedHider() then
		return if useTouch then "↩️ กลับมาดูตัวเอง" else "↩️ กลับมาดูตัวเอง [V]"
	else
		return "✖️ หยุดดูการแข่งขัน"
	end
end

local function exitSpectateMode()
	isSpectating = false
	switcherBar.Visible = false
	spectateButton.Text = getDefaultButtonLabel()

	local myCharacter = localPlayer.Character
	local myHumanoid = myCharacter and myCharacter:FindFirstChildOfClass("Humanoid")
	if myHumanoid then
		camera.CameraSubject = myHumanoid
	end
end

local function applySpectateCamera()
	if not isSpectating then
		return
	end

	local targets = getSpectatableTargets()
	if #targets == 0 then
		if isLocalPlayerLockedHider() then
			switcherBar.Visible = true
			spectatedNameLabel.Text = "ไม่มีเพื่อนคนอื่นซ่อนอยู่ (คุณซ่อนคนเดียว)"
			local myChar = localPlayer.Character
			local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")
			if myHum then
				camera.CameraSubject = myHum
			end
			return
		end

		exitSpectateMode()
		return
	end

	if currentTargetIndex > #targets then
		currentTargetIndex = 1
	elseif currentTargetIndex < 1 then
		currentTargetIndex = #targets
	end

	local targetPlayer = targets[currentTargetIndex]
	local targetChar = targetPlayer.Character
	local targetHumanoid = targetChar and targetChar:FindFirstChildOfClass("Humanoid")

	if targetHumanoid then
		camera.CameraSubject = targetHumanoid
		local propModel = targetChar and targetChar:FindFirstChild("MorphedProp")
		local roleOrProp = if isLocalPlayerLockedHider()
			then (if propModel then "ซ่อนอยู่" else "ยังไม่แปลงร่าง")
			else (if targetPlayer.Team then targetPlayer.Team.Name else "")
		spectatedNameLabel.Text = string.format("👁️ %s (%s)", targetPlayer.DisplayName, roleOrProp)
	end
end

local function toggleSpectate()
	if isSpectating then
		exitSpectateMode()
	else
		local targets = getSpectatableTargets()
		if #targets > 0 or isLocalPlayerLockedHider() then
			isSpectating = true
			switcherBar.Visible = true
			spectateButton.Text = getActiveStopSpectateLabel()
			applySpectateCamera()
		end
	end
end

local function updateSpectateAvailability()
	local roundState = workspace:GetAttribute("RoundState")
	local isRoundActive = (roundState == "HidingPhase" or roundState == "HuntingPhase" or roundState == "RoundOver")
	local lobbyOpen = localPlayer:GetAttribute("LobbyMenuOpen") == true

	local myTeamName = if localPlayer.Team then localPlayer.Team.Name else "Lobby"
	local myCharacter = localPlayer.Character
	local myHumanoid = myCharacter and myCharacter:FindFirstChildOfClass("Humanoid")
	local isDead = not myHumanoid or myHumanoid.Health <= 0
	local lockedHider = isLocalPlayerLockedHider()

	local canSpectate = lockedHider or (isRoundActive and (myTeamName == "Lobby" or isDead) and not lobbyOpen)

	if canSpectate then
		spectateButton.Visible = true
		if not isSpectating then
			spectateButton.Text = getDefaultButtonLabel()
		else
			spectateButton.Text = getActiveStopSpectateLabel()
			applySpectateCamera()
		end
	else
		spectateButton.Visible = false
		if isSpectating then
			exitSpectateMode()
		end
	end
end

spectateButton.Activated:Connect(toggleSpectate)

prevArrowBtn.Activated:Connect(function()
	currentTargetIndex -= 1
	applySpectateCamera()
end)

nextArrowBtn.Activated:Connect(function()
	currentTargetIndex += 1
	applySpectateCamera()
end)

ContextActionService:BindAction("SpectateTeammatesToggle", function(_name, state, _input)
	if state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	if spectateButton.Visible then
		toggleSpectate()
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.V)

--------------------------------------------------------------------------------
-- 3. HIDER PROP CAMERA OFFSET & LOCAL TRANSPARENCY
--------------------------------------------------------------------------------
RunService.RenderStepped:Connect(function()
	local character = localPlayer.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local morphedProp = character:FindFirstChild("MorphedProp")

	if not humanoid or not rootPart then
		return
	end

	if morphedProp and not isSpectating then
		local propHeight = 4
		if morphedProp:IsA("Model") then
			local _, bboxSize = morphedProp:GetBoundingBox()
			propHeight = bboxSize.Y
		elseif morphedProp:IsA("BasePart") then
			propHeight = morphedProp.Size.Y
		end

		local targetYOffset = math.clamp((propHeight - 4) * 0.35, 0, 2.5)
		humanoid.CameraOffset = humanoid.CameraOffset:Lerp(Vector3.new(0, targetYOffset, 0), 0.15)

		local camDist = (camera.CFrame.Position - rootPart.Position).Magnitude
		local localModifier = if camDist < 8 then 0.55 else 0

		if morphedProp:IsA("BasePart") then
			morphedProp.LocalTransparencyModifier = localModifier
		elseif morphedProp:IsA("Model") then
			for _, desc in morphedProp:GetDescendants() do
				if desc:IsA("BasePart") then
					desc.LocalTransparencyModifier = localModifier
				end
			end
		end
	elseif localPlayer.Team ~= nil and localPlayer.Team.Name == "Seekers" and not isSpectating then
		-- Over-the-shoulder TPS camera offset for Seekers so their own head never blocks the center crosshair!
		local zoomDist = (camera.CFrame.Position - camera.Focus.Position).Magnitude
		local targetSeekerOffset = if zoomDist < 1.8 then Vector3.zero else Vector3.new(1.85, 0.85, 0)
		humanoid.CameraOffset = humanoid.CameraOffset:Lerp(targetSeekerOffset, 0.2)
	else
		humanoid.CameraOffset = Vector3.zero
	end
end)

workspace:GetAttributeChangedSignal("RoundState"):Connect(function()
	updateSeekerBlindfold()
	updateSpectateAvailability()
end)

workspace:GetAttributeChangedSignal("RoundTimer"):Connect(updateSeekerBlindfold)
localPlayer:GetAttributeChangedSignal("IsBlindfolded"):Connect(updateSeekerBlindfold)
localPlayer:GetAttributeChangedSignal("LobbyMenuOpen"):Connect(updateSpectateAvailability)

localPlayer:GetPropertyChangedSignal("Team"):Connect(function()
	updateSeekerBlindfold()
	updateSpectateAvailability()
end)

local lockAttrConnection: RBXScriptConnection? = nil

local function bindCharacter(character: Model)
	if lockAttrConnection then
		lockAttrConnection:Disconnect()
		lockAttrConnection = nil
	end

	updateSeekerBlindfold()
	updateSpectateAvailability()

	lockAttrConnection = character:GetAttributeChangedSignal("IsPropLocked"):Connect(function()
		updateSpectateAvailability()
	end)

	local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
	if humanoid then
		humanoid.Died:Connect(updateSpectateAvailability)
	end
end

if localPlayer.Character then
	task.spawn(bindCharacter, localPlayer.Character)
end
localPlayer.CharacterAdded:Connect(bindCharacter)

updateSeekerBlindfold()
updateSpectateAvailability()
