--!strict
-- StarterPlayerScripts/Client/SpectateAndCamera.client.luau
-- Implements:
-- 1. Hider Prop Camera Helper: Lifts camera offset slightly for tall props and applies LocalTransparencyModifier
--    when zooming close to the local player's own prop.
-- 2. Seeker Blindfold during Hiding Phase: Covers the Seeker's screen with a black Frame and live countdown.
-- 3. Spectator Camera System (Lobby + Locked Hiders!):
--    - Lobby / Eliminated Players: Can spectate all living players in the round.
--    - Locked Hiders (after pressing [F] to lock): Can click "ส่องดูเพื่อนที่ซ่อนอยู่ [V]" (or press V) to cycle
--      through fellow living Hiders using "<" and ">", and automatically returns to their own camera the instant
--      they unlock [F] or take damage!

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local Teams = game:GetService("Teams")

local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera
local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui

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
-- 1. SEEKER BLINDFOLD OVERLAY (Black Frame + Countdown during Hiding Phase)
--------------------------------------------------------------------------------
local blindfoldFrame = Instance.new("Frame")
blindfoldFrame.Name = "SeekerBlindfoldFrame"
blindfoldFrame.Size = UDim2.fromScale(1, 1)
blindfoldFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
blindfoldFrame.BorderSizePixel = 0
blindfoldFrame.Visible = false
blindfoldFrame.ZIndex = 15
blindfoldFrame.Parent = qolGui

local blindfoldTitle = Instance.new("TextLabel")
blindfoldTitle.Name = "BlindfoldTitle"
blindfoldTitle.Size = UDim2.new(0.8, 0, 0, 50)
blindfoldTitle.Position = UDim2.new(0.5, 0, 0.45, 0)
blindfoldTitle.AnchorPoint = Vector2.new(0.5, 0.5)
blindfoldTitle.BackgroundTransparency = 1
blindfoldTitle.Font = Enum.Font.GothamBlack
blindfoldTitle.TextSize = 30
blindfoldTitle.TextColor3 = Color3.fromRGB(255, 90, 90)
blindfoldTitle.Text = "Hiders are hiding... Get ready!"
blindfoldTitle.ZIndex = 16
blindfoldTitle.Parent = blindfoldFrame

local blindfoldCountdown = Instance.new("TextLabel")
blindfoldCountdown.Name = "BlindfoldCountdown"
blindfoldCountdown.Size = UDim2.new(0.6, 0, 0, 60)
blindfoldCountdown.Position = UDim2.new(0.5, 0, 0.54, 0)
blindfoldCountdown.AnchorPoint = Vector2.new(0.5, 0.5)
blindfoldCountdown.BackgroundTransparency = 1
blindfoldCountdown.Font = Enum.Font.GothamBlack
blindfoldCountdown.TextSize = 44
blindfoldCountdown.TextColor3 = Color3.fromRGB(255, 255, 255)
blindfoldCountdown.Text = "30s"
blindfoldCountdown.ZIndex = 16
blindfoldCountdown.Parent = blindfoldFrame

local function updateSeekerBlindfold()
	local roundState = workspace:GetAttribute("RoundState")
	local roundTimer = workspace:GetAttribute("RoundTimer")
	local seekersTeam = Teams:FindFirstChild("Seekers")

	local isSeeker = seekersTeam ~= nil and localPlayer.Team == seekersTeam
	local shouldBlind = isSeeker and (roundState == "HidingPhase" or localPlayer:GetAttribute("IsBlindfolded") == true)

	blindfoldFrame.Visible = shouldBlind

	if shouldBlind then
		local secondsLeft = if typeof(roundTimer) == "number" then math.max(0, math.ceil(roundTimer)) else 0
		blindfoldTitle.Text = "Hiders are hiding... Get ready!"
		blindfoldCountdown.Text = string.format("Releasing in %ds", secondsLeft)

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

-- Main "Spectate" Toggle Button
local spectateButton = Instance.new("TextButton")
spectateButton.Name = "SpectateToggleButton"
spectateButton.Size = UDim2.new(0, 220, 0, 42)
spectateButton.Position = UDim2.new(0.5, 0, 1, -22)
spectateButton.AnchorPoint = Vector2.new(0.5, 1)
spectateButton.BackgroundColor3 = Color3.fromRGB(24, 28, 38)
spectateButton.Font = Enum.Font.GothamBold
spectateButton.TextSize = 15
spectateButton.TextColor3 = Color3.fromRGB(255, 255, 255)
spectateButton.Text = "ส่องดูเพื่อนที่ซ่อนอยู่ [V]"
spectateButton.Visible = false
spectateButton.ZIndex = 20
spectateButton.Parent = qolGui

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 10)
btnCorner.Parent = spectateButton

local btnStroke = Instance.new("UIStroke")
btnStroke.Color = Color3.fromRGB(85, 195, 255)
btnStroke.Thickness = 1.5
btnStroke.Parent = spectateButton

-- Spectator Switcher Bar ("<" | Player Name | ">")
local switcherBar = Instance.new("Frame")
switcherBar.Name = "SpectatorSwitcherBar"
switcherBar.Size = UDim2.new(0, 340, 0, 48)
switcherBar.Position = UDim2.new(0.5, 0, 1, -74)
switcherBar.AnchorPoint = Vector2.new(0.5, 1)
switcherBar.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
switcherBar.BackgroundTransparency = 0.1
switcherBar.Visible = false
switcherBar.ZIndex = 20
switcherBar.Parent = qolGui

local barCorner = Instance.new("UICorner")
barCorner.CornerRadius = UDim.new(0, 10)
barCorner.Parent = switcherBar

local barStroke = Instance.new("UIStroke")
barStroke.Color = Color3.fromRGB(70, 78, 100)
barStroke.Thickness = 1.5
barStroke.Parent = switcherBar

local prevArrowBtn = Instance.new("TextButton")
prevArrowBtn.Name = "PrevButton"
prevArrowBtn.Size = UDim2.new(0, 48, 1, 0)
prevArrowBtn.Position = UDim2.new(0, 0, 0, 0)
prevArrowBtn.BackgroundTransparency = 1
prevArrowBtn.Font = Enum.Font.GothamBlack
prevArrowBtn.TextSize = 22
prevArrowBtn.TextColor3 = Color3.fromRGB(85, 170, 255)
prevArrowBtn.Text = "<"
prevArrowBtn.ZIndex = 21
prevArrowBtn.Parent = switcherBar

local nextArrowBtn = Instance.new("TextButton")
nextArrowBtn.Name = "NextButton"
nextArrowBtn.Size = UDim2.new(0, 48, 1, 0)
nextArrowBtn.Position = UDim2.new(1, -48, 0, 0)
nextArrowBtn.BackgroundTransparency = 1
nextArrowBtn.Font = Enum.Font.GothamBlack
nextArrowBtn.TextSize = 22
nextArrowBtn.TextColor3 = Color3.fromRGB(85, 170, 255)
nextArrowBtn.Text = ">"
nextArrowBtn.ZIndex = 21
nextArrowBtn.Parent = switcherBar

local spectatedNameLabel = Instance.new("TextLabel")
spectatedNameLabel.Name = "SpectatedNameLabel"
spectatedNameLabel.Size = UDim2.new(1, -96, 1, 0)
spectatedNameLabel.Position = UDim2.new(0, 48, 0, 0)
spectatedNameLabel.BackgroundTransparency = 1
spectatedNameLabel.Font = Enum.Font.GothamBold
spectatedNameLabel.TextSize = 14
spectatedNameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
spectatedNameLabel.Text = "กำลังดูเพื่อน..."
spectatedNameLabel.TextTruncate = Enum.TextTruncate.AtEnd
spectatedNameLabel.ZIndex = 21
spectatedNameLabel.Parent = switcherBar

-- Helper: Check if the local player is currently a Locked Hider
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

-- Helper: Collect spectatable players
-- - If the local player is a Locked Hider: Only return fellow living Hiders (teammates hiding with us)!
-- - If the local player is in the Lobby / dead: Return all living Hiders and Seekers.
local function getSpectatableTargets(): { Player }
	local targets: { Player } = {}
	local hidersTeam = Teams:FindFirstChild("Hiders")
	local seekersTeam = Teams:FindFirstChild("Seekers")
	local lockedHiderMode = isLocalPlayerLockedHider()

	for _, player in Players:GetPlayers() do
		if lockedHiderMode then
			-- Only fellow living players on the Hiders team (excluding self first; if none, allow self as fallback)
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
	if isLocalPlayerLockedHider() then
		return "ส่องดูเพื่อนที่ซ่อนอยู่ [V]"
	else
		return "ดูการแข่งขัน (Spectate)"
	end
end

-- Exit spectate mode and restore camera to local player's own Humanoid
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

-- Update CameraSubject to the currently selected living teammate/player
local function applySpectateCamera()
	if not isSpectating then
		return
	end

	local targets = getSpectatableTargets()
	if #targets == 0 then
		-- If a locked Hider has no other Hider teammates in the server (e.g., solo testing), show a friendly message
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
		-- Show what prop the teammate is disguised as if they morphed!
		local propModel = targetChar and targetChar:FindFirstChild("MorphedProp")
		local roleOrProp = if isLocalPlayerLockedHider()
			then (if propModel then "ซ่อนอยู่" else "ยังไม่แปลงร่าง")
			else (if targetPlayer.Team then targetPlayer.Team.Name else "")
		spectatedNameLabel.Text = string.format("ดูเพื่อน: %s (%s)", targetPlayer.DisplayName, roleOrProp)
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
			spectateButton.Text = if isLocalPlayerLockedHider()
				then "กลับมาดูตัวเอง [V]"
				else "หยุดดู (Stop Spectating)"
			applySpectateCamera()
		end
	end
end

-- Update whether the Spectate button is available:
-- Available if:
--   (A) Local player is a Hider and has locked their prop with [F] (`IsPropLocked == true`), OR
--   (B) Local player is in the Lobby / dead during an active round
local function updateSpectateAvailability()
	local roundState = workspace:GetAttribute("RoundState")
	local isRoundActive = (roundState == "HidingPhase" or roundState == "HuntingPhase")

	local myTeamName = if localPlayer.Team then localPlayer.Team.Name else "Lobby"
	local myCharacter = localPlayer.Character
	local myHumanoid = myCharacter and myCharacter:FindFirstChildOfClass("Humanoid")
	local isDead = not myHumanoid or myHumanoid.Health <= 0
	local lockedHider = isLocalPlayerLockedHider()

	local canSpectate = lockedHider or (isRoundActive and (myTeamName == "Lobby" or isDead))

	if canSpectate then
		spectateButton.Visible = true
		if not isSpectating then
			spectateButton.Text = getDefaultButtonLabel()
		else
			spectateButton.Text = if lockedHider then "กลับมาดูตัวเอง [V]" else "หยุดดู (Stop Spectating)"
			applySpectateCamera()
		end
	else
		-- Immediately exit spectate mode if the Hider unlocks [F] or a new round starts!
		spectateButton.Visible = false
		if isSpectating then
			exitSpectateMode()
		end
	end
end

-- Button & Keybind Connections
spectateButton.Activated:Connect(toggleSpectate)

prevArrowBtn.Activated:Connect(function()
	currentTargetIndex -= 1
	applySpectateCamera()
end)

nextArrowBtn.Activated:Connect(function()
	currentTargetIndex += 1
	applySpectateCamera()
end)

-- Allow Locked Hiders to press [V] to quickly toggle spectating teammates
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
	else
		humanoid.CameraOffset = Vector3.zero
	end
end)

-- Connect Signals for Blindfold, Prop Lock & Spectator State
workspace:GetAttributeChangedSignal("RoundState"):Connect(function()
	updateSeekerBlindfold()
	updateSpectateAvailability()
end)

workspace:GetAttributeChangedSignal("RoundTimer"):Connect(updateSeekerBlindfold)
localPlayer:GetAttributeChangedSignal("IsBlindfolded"):Connect(updateSeekerBlindfold)

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

	-- Listen to [F] Prop Lock state so the "Spectate Teammates" button appears when locked and auto-exits when unlocked!
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

-- Initial sync
updateSeekerBlindfold()
updateSpectateAvailability()
