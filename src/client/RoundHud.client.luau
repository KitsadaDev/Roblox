--!strict
-- StarterPlayerScripts/Client/RoundHud.client.luau
-- Procedurally generates the entire Prop Hunt Game HUD (ScreenGui) via code:
-- 1. Top Status Bar (Top-Center): StateLabel + TimerLabel (MM:SS) listening to Workspace attributes
-- 2. Role & Health Indicator (Bottom-Left): Color-coded Role ("Lobby", "Hider", "Seeker") + Dynamic Health Bar
-- 3. Hider Controls Hint (Bottom-Right): Only visible when on "Hiders" team ("[Click/E] Morph", "[F] Lock Position", "[T] Taunt (+10 Coins)")
-- 4. Seeker Blindfold Overlay: Shown when the Seeker is waiting during the Hiding Phase

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui

--------------------------------------------------------------------------------
-- UI STYLING CONSTANTS
--------------------------------------------------------------------------------
local PANEL_BG_COLOR = Color3.fromRGB(20, 22, 30)
local PANEL_STROKE_COLOR = Color3.fromRGB(70, 78, 100)

local ROLE_COLORS = {
	Lobby = Color3.fromRGB(190, 195, 210),
	Hiders = Color3.fromRGB(75, 185, 255),
	Seekers = Color3.fromRGB(255, 85, 85),
}

-- Helper to apply rounded corners and stroke to a Frame
local function stylePanel(frame: Frame, cornerRadius: number, strokeColor: Color3?)
	frame.BackgroundColor3 = PANEL_BG_COLOR
	frame.BackgroundTransparency = 0.12
	frame.BorderSizePixel = 0

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, cornerRadius)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = strokeColor or PANEL_STROKE_COLOR
	stroke.Thickness = 1.5
	stroke.Transparency = 0.25
	stroke.Parent = frame
end

--------------------------------------------------------------------------------
-- CREATE MAIN SCREENGUI
--------------------------------------------------------------------------------
local existingGui = playerGui:FindFirstChild("PropHuntHud")
if existingGui then
	existingGui:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PropHuntHud"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

--------------------------------------------------------------------------------
-- 1. TOP STATUS BAR (Top-Center: StateLabel + TimerLabel formatted as MM:SS)
--------------------------------------------------------------------------------
local topBarFrame = Instance.new("Frame")
topBarFrame.Name = "TopStatusBar"
topBarFrame.Size = UDim2.new(0, 340, 0, 68)
topBarFrame.Position = UDim2.new(0.5, 0, 0, 16)
topBarFrame.AnchorPoint = Vector2.new(0.5, 0)
topBarFrame.ZIndex = 20
stylePanel(topBarFrame, 12)
topBarFrame.Parent = screenGui

local stateLabel = Instance.new("TextLabel")
stateLabel.Name = "StateLabel"
stateLabel.Size = UDim2.new(1, -24, 0, 24)
stateLabel.Position = UDim2.new(0.5, 0, 0, 8)
stateLabel.AnchorPoint = Vector2.new(0.5, 0)
stateLabel.BackgroundTransparency = 1
stateLabel.Font = Enum.Font.GothamBold
stateLabel.TextSize = 15
stateLabel.TextColor3 = Color3.fromRGB(185, 195, 220)
stateLabel.Text = "WAITING FOR PLAYERS"
stateLabel.ZIndex = 21
stateLabel.Parent = topBarFrame

local timerLabel = Instance.new("TextLabel")
timerLabel.Name = "TimerLabel"
timerLabel.Size = UDim2.new(1, -24, 0, 32)
timerLabel.Position = UDim2.new(0.5, 0, 0, 31)
timerLabel.AnchorPoint = Vector2.new(0.5, 0)
timerLabel.BackgroundTransparency = 1
timerLabel.Font = Enum.Font.GothamBlack
timerLabel.TextSize = 26
timerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
timerLabel.Text = "00:00"
timerLabel.ZIndex = 21
timerLabel.Parent = topBarFrame

--------------------------------------------------------------------------------
-- 2. ROLE & HEALTH INDICATOR (Bottom-Left)
--------------------------------------------------------------------------------
local roleHealthFrame = Instance.new("Frame")
roleHealthFrame.Name = "RoleHealthIndicator"
roleHealthFrame.Size = UDim2.new(0, 260, 0, 78)
roleHealthFrame.Position = UDim2.new(0, 20, 1, -20)
roleHealthFrame.AnchorPoint = Vector2.new(0, 1)
roleHealthFrame.ZIndex = 20
stylePanel(roleHealthFrame, 12)
roleHealthFrame.Parent = screenGui

local roleLabel = Instance.new("TextLabel")
roleLabel.Name = "RoleLabel"
roleLabel.Size = UDim2.new(1, -28, 0, 26)
roleLabel.Position = UDim2.new(0, 14, 0, 10)
roleLabel.BackgroundTransparency = 1
roleLabel.Font = Enum.Font.GothamBlack
roleLabel.TextSize = 18
roleLabel.TextXAlignment = Enum.TextXAlignment.Left
roleLabel.TextColor3 = ROLE_COLORS.Lobby
roleLabel.Text = "ROLE: LOBBY"
roleLabel.ZIndex = 21
roleLabel.Parent = roleHealthFrame

-- Health Bar Background
local healthBarBg = Instance.new("Frame")
healthBarBg.Name = "HealthBarBackground"
healthBarBg.Size = UDim2.new(1, -28, 0, 22)
healthBarBg.Position = UDim2.new(0, 14, 0, 44)
healthBarBg.BackgroundColor3 = Color3.fromRGB(38, 42, 54)
healthBarBg.BorderSizePixel = 0
healthBarBg.ZIndex = 21
healthBarBg.Parent = roleHealthFrame

local healthBgCorner = Instance.new("UICorner")
healthBgCorner.CornerRadius = UDim.new(0, 6)
healthBgCorner.Parent = healthBarBg

-- Health Bar Fill
local healthBarFill = Instance.new("Frame")
healthBarFill.Name = "HealthBarFill"
healthBarFill.Size = UDim2.fromScale(1, 1)
healthBarFill.BackgroundColor3 = Color3.fromRGB(65, 215, 110)
healthBarFill.BorderSizePixel = 0
healthBarFill.ZIndex = 22
healthBarFill.Parent = healthBarBg

local healthFillCorner = Instance.new("UICorner")
healthFillCorner.CornerRadius = UDim.new(0, 6)
healthFillCorner.Parent = healthBarFill

-- Health Numeric Text Overlay
local healthValueLabel = Instance.new("TextLabel")
healthValueLabel.Name = "HealthValueLabel"
healthValueLabel.Size = UDim2.fromScale(1, 1)
healthValueLabel.BackgroundTransparency = 1
healthValueLabel.Font = Enum.Font.GothamBold
healthValueLabel.TextSize = 13
healthValueLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
healthValueLabel.Text = "100 / 100 HP"
healthValueLabel.ZIndex = 23
healthValueLabel.Parent = healthBarBg

--------------------------------------------------------------------------------
-- 3. HIDER & SEEKER CONTROLS HINT (Bottom-Right)
--------------------------------------------------------------------------------
local hiderControlsFrame = Instance.new("Frame")
hiderControlsFrame.Name = "HiderControlsHint"
hiderControlsFrame.Size = UDim2.new(0, 275, 0, 156)
hiderControlsFrame.Position = UDim2.new(1, -20, 1, -20)
hiderControlsFrame.AnchorPoint = Vector2.new(1, 1)
hiderControlsFrame.Visible = false
hiderControlsFrame.ZIndex = 20
stylePanel(hiderControlsFrame, 12, Color3.fromRGB(75, 185, 255))
hiderControlsFrame.Parent = screenGui

local controlsHeader = Instance.new("TextLabel")
controlsHeader.Name = "Header"
controlsHeader.Size = UDim2.new(1, -24, 0, 22)
controlsHeader.Position = UDim2.new(0, 12, 0, 8)
controlsHeader.BackgroundTransparency = 1
controlsHeader.Font = Enum.Font.GothamBlack
controlsHeader.TextSize = 14
controlsHeader.TextXAlignment = Enum.TextXAlignment.Left
controlsHeader.TextColor3 = Color3.fromRGB(75, 185, 255)
controlsHeader.Text = "HIDER CONTROLS"
controlsHeader.ZIndex = 21
controlsHeader.Parent = hiderControlsFrame

local function createControlHintRow(name: string, text: string, yOffset: number): TextLabel
	local row = Instance.new("TextLabel")
	row.Name = name
	row.Size = UDim2.new(1, -24, 0, 20)
	row.Position = UDim2.new(0, 12, 0, yOffset)
	row.BackgroundTransparency = 1
	row.Font = Enum.Font.GothamMedium
	row.TextSize = 13
	row.TextXAlignment = Enum.TextXAlignment.Left
	row.TextColor3 = Color3.fromRGB(230, 235, 245)
	row.Text = text
	row.ZIndex = 21
	row.Parent = hiderControlsFrame
	return row
end

local morphHintLabel = createControlHintRow("MorphHint", "[Click/E] Morph", 34)
local lockHintLabel = createControlHintRow("LockHint", "[F] Lock Position  |  [R] Rotate 45°", 56)
local tauntHintLabel = createControlHintRow("TauntHint", "[T] Taunt (+10 Coins)", 78)
local decoyHintLabel = createControlHintRow("DecoyHint", "[G] Spawn Decoy (20 Coins)", 100)
local sprintHintLabel = createControlHintRow("SprintHint", "[Shift] Smoke Sprint (Escape)", 122)

--------------------------------------------------------------------------------
-- 4. SEEKER BLINDFOLD OVERLAY (Shown when Seeker is waiting in Hiding Phase)
--------------------------------------------------------------------------------
local blindfoldOverlay = Instance.new("Frame")
blindfoldOverlay.Name = "SeekerBlindfoldOverlay"
blindfoldOverlay.Size = UDim2.fromScale(1, 1)
blindfoldOverlay.BackgroundColor3 = Color3.fromRGB(10, 11, 16)
blindfoldOverlay.Visible = false
blindfoldOverlay.ZIndex = 10
blindfoldOverlay.Parent = screenGui

local blindfoldText = Instance.new("TextLabel")
blindfoldText.Size = UDim2.new(0.8, 0, 0, 80)
blindfoldText.Position = UDim2.fromScale(0.5, 0.5)
blindfoldText.AnchorPoint = Vector2.new(0.5, 0.5)
blindfoldText.BackgroundTransparency = 1
blindfoldText.Font = Enum.Font.GothamBlack
blindfoldText.TextSize = 28
blindfoldText.TextColor3 = Color3.fromRGB(255, 85, 85)
blindfoldText.Text = "YOU ARE THE SEEKER!\nHiders are currently hiding..."
blindfoldText.ZIndex = 11
blindfoldText.Parent = blindfoldOverlay

--------------------------------------------------------------------------------
-- REAL-TIME UPDATE LOGIC
--------------------------------------------------------------------------------
-- Format seconds as MM:SS
local function formatTimeMMSS(totalSeconds: number): string
	local clamped = math.max(0, math.floor(totalSeconds))
	local minutes = math.floor(clamped / 60)
	local seconds = clamped % 60
	return string.format("%02d:%02d", minutes, seconds)
end

-- 1. Update Top Status Bar from Workspace Attributes
local function updateTopStatusBar()
	local rawState = workspace:GetAttribute("RoundState")
	local rawTimer = workspace:GetAttribute("RoundTimer")
	local rawStatus = workspace:GetAttribute("RoundStatus")

	local timerNum = if typeof(rawTimer) == "number" then rawTimer else 0
	timerLabel.Text = formatTimeMMSS(timerNum)

	if rawState == "Intermission" then
		stateLabel.Text = "INTERMISSION"
		stateLabel.TextColor3 = Color3.fromRGB(185, 195, 220)
	elseif rawState == "HidingPhase" then
		stateLabel.Text = "HIDING PHASE"
		stateLabel.TextColor3 = Color3.fromRGB(75, 185, 255)
	elseif rawState == "HuntingPhase" then
		stateLabel.Text = "HUNTING PHASE"
		stateLabel.TextColor3 = Color3.fromRGB(255, 95, 95)
	elseif rawState == "RoundOver" then
		-- Show the exact winner announcement (e.g. "Seekers Win! (+50 Coins)")
		stateLabel.Text = if typeof(rawStatus) == "string" then string.upper(rawStatus) else "ROUND OVER"
		stateLabel.TextColor3 = Color3.fromRGB(255, 215, 70)
	else
		stateLabel.Text = "WAITING FOR PLAYERS"
		stateLabel.TextColor3 = Color3.fromRGB(185, 195, 220)
	end
end

-- 2. Update Role Text & Hider Controls Visibility
local function updateRoleAndControls()
	local teamName = if localPlayer.Team then localPlayer.Team.Name else "Lobby"
	local character = localPlayer.Character
	local isLocked = character and character:GetAttribute("IsPropLocked") == true

	if teamName == "Hiders" then
		roleLabel.Text = if isLocked then "ROLE: HIDER [LOCKED]" else "ROLE: HIDER"
		roleLabel.TextColor3 = ROLE_COLORS.Hiders
		hiderControlsFrame.Visible = true

		lockHintLabel.Text = if isLocked
			then "[F] ปลดล็อก  |  [V] ส่องดูเพื่อน"
			else "[F] Lock Position  |  [R] Rotate 45°"
		lockHintLabel.TextColor3 = if isLocked
			then Color3.fromRGB(85, 255, 145)
			else Color3.fromRGB(230, 235, 245)
	elseif teamName == "Seekers" then
		roleLabel.Text = "ROLE: SEEKER"
		roleLabel.TextColor3 = ROLE_COLORS.Seekers
		hiderControlsFrame.Visible = false
	else
		roleLabel.Text = "ROLE: LOBBY"
		roleLabel.TextColor3 = ROLE_COLORS.Lobby
		hiderControlsFrame.Visible = false
	end

	-- Keep silence warning unused variable checks
	local _ = morphHintLabel
	local _ = tauntHintLabel
	local _ = decoyHintLabel
	local _ = sprintHintLabel
end

-- 3. Update Dynamic Health Bar
local function updateHealthBar(health: number, maxHealth: number)
	local safeMax = if maxHealth > 0 then maxHealth else 100
	local ratio = math.clamp(health / safeMax, 0, 1)

	healthValueLabel.Text = string.format("%d / %d HP", math.ceil(math.max(0, health)), math.ceil(safeMax))

	-- Color transitions from Green -> Yellow -> Red based on health ratio
	local fillColor: Color3
	if ratio > 0.5 then
		fillColor = Color3.fromRGB(65, 215, 110)
	elseif ratio > 0.25 then
		fillColor = Color3.fromRGB(245, 185, 55)
	else
		fillColor = Color3.fromRGB(240, 70, 70)
	end

	TweenService:Create(healthBarFill, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromScale(ratio, 1),
		BackgroundColor3 = fillColor,
	}):Play()
end

-- Bind Character Humanoid Health & PropLock Attribute
local healthConnection: RBXScriptConnection? = nil
local lockConnection: RBXScriptConnection? = nil

local function bindCharacter(character: Model)
	if healthConnection then
		healthConnection:Disconnect()
		healthConnection = nil
	end
	if lockConnection then
		lockConnection:Disconnect()
		lockConnection = nil
	end

	updateRoleAndControls()
	lockConnection = character:GetAttributeChangedSignal("IsPropLocked"):Connect(updateRoleAndControls)

	local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
	if humanoid then
		updateHealthBar(humanoid.Health, humanoid.MaxHealth)
		healthConnection = humanoid.HealthChanged:Connect(function(newHealth: number)
			updateHealthBar(newHealth, humanoid.MaxHealth)
		end)
	end
end

-- Connect Signals
workspace:GetAttributeChangedSignal("RoundState"):Connect(updateTopStatusBar)
workspace:GetAttributeChangedSignal("RoundTimer"):Connect(updateTopStatusBar)
workspace:GetAttributeChangedSignal("RoundStatus"):Connect(updateTopStatusBar)

localPlayer:GetPropertyChangedSignal("Team"):Connect(updateRoleAndControls)

if localPlayer.Character then
	task.spawn(bindCharacter, localPlayer.Character)
end
localPlayer.CharacterAdded:Connect(bindCharacter)

-- Run initial sync
updateTopStatusBar()
updateRoleAndControls()
