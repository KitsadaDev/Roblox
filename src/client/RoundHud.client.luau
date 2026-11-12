--!strict
-- StarterPlayerScripts/Client/RoundHud.client.luau
-- Procedurally generates the entire Prop Hunt Game HUD (ScreenGui) via code:
-- 1. Top Status Bar (Top-Center): StateLabel + TimerLabel (MM:SS) listening to Workspace attributes
-- 2. Role & Health Indicator (Bottom-Left): Color-coded Role ("Lobby", "Hider", "Seeker") + Dynamic Health Bar
-- 3. Hider Controls Hint (Bottom-Right): Only visible when on "Hiders" team ("[Click/E] Morph", "[F] Lock Position", "[T] Taunt (+10 Coins)")
-- 4. Seeker Blindfold Overlay: Shown when the Seeker is waiting during the Hiding Phase

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui

local PropRemotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PropRemotes"))
local roundEventNotice = PropRemotes.RoundEventNotice

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
local tauntHintLabel = createControlHintRow("TauntHint", "[T] Taunt (+5~20 Coins, Max 50)", 78)
local decoyHintLabel = createControlHintRow("DecoyHint", "[G] Spawn Decoy (20 Coins)", 100)
local sprintHintLabel = createControlHintRow("SprintHint", "[Shift] Smoke Sprint (Escape)", 122)

-- Seeker Controls Hint Frame (Bottom-Right when on Seekers team!)
local seekerControlsFrame = Instance.new("Frame")
seekerControlsFrame.Name = "SeekerControlsHint"
seekerControlsFrame.Size = UDim2.new(0, 275, 0, 114)
seekerControlsFrame.Position = UDim2.new(1, -20, 1, -20)
seekerControlsFrame.AnchorPoint = Vector2.new(1, 1)
seekerControlsFrame.Visible = false
seekerControlsFrame.ZIndex = 20
stylePanel(seekerControlsFrame, 12, Color3.fromRGB(255, 85, 85))
seekerControlsFrame.Parent = screenGui

local seekerControlsHeader = Instance.new("TextLabel")
seekerControlsHeader.Name = "Header"
seekerControlsHeader.Size = UDim2.new(1, -24, 0, 22)
seekerControlsHeader.Position = UDim2.new(0, 12, 0, 8)
seekerControlsHeader.BackgroundTransparency = 1
seekerControlsHeader.Font = Enum.Font.GothamBlack
seekerControlsHeader.TextSize = 14
seekerControlsHeader.TextXAlignment = Enum.TextXAlignment.Left
seekerControlsHeader.TextColor3 = Color3.fromRGB(255, 95, 95)
seekerControlsHeader.Text = "SEEKER CONTROLS"
seekerControlsHeader.ZIndex = 21
seekerControlsHeader.Parent = seekerControlsFrame

local function createSeekerHintRow(name: string, text: string, yOffset: number): TextLabel
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
	row.Parent = seekerControlsFrame
	return row
end

local seekerAttackHint = createSeekerHintRow("AttackHint", "[Click] โจมตี (-50 HP / พลาด -15 HP)", 34)
local seekerRadarHint = createSeekerHintRow("RadarHint", "[Q] Sonar Radar (สแกนระยะ Hider)", 58)
local seekerSurgeHint = createSeekerHintRow("SurgeHint", "[E] Speed Surge (วิ่งไวไล่ล่า 4s)", 82)

-- Live Cooldown Countdown Tracker
local cooldownExpiries: { [string]: number } = {}

task.spawn(function()
	while true do
		task.wait(0.2)
		local now = os.clock()

		local function getRemain(key: string): number
			local exp = cooldownExpiries[key]
			return if exp and exp > now then math.ceil(exp - now) else 0
		end

		local tRem = getRemain("Taunt")
		tauntHintLabel.Text = if tRem > 0
			then string.format("[T] Taunt (⏳ %ds)", tRem)
			else "[T] Taunt (+5~20 Coins, Max 50)"

		local dRem = getRemain("SpawnDecoy")
		decoyHintLabel.Text = if dRem > 0
			then string.format("[G] Spawn Decoy (⏳ %ds)", dRem)
			else "[G] Spawn Decoy (20 Coins)"

		local sRem = getRemain("SmokeSprint")
		sprintHintLabel.Text = if sRem > 0
			then string.format("[Shift] Smoke Sprint (⏳ %ds)", sRem)
			else "[Shift] Smoke Sprint (Escape)"

		local rRem = getRemain("SeekerRadar")
		seekerRadarHint.Text = if rRem > 0
			then string.format("[Q] Sonar Radar (⏳ %ds)", rRem)
			else "[Q] Sonar Radar (สแกนระยะ Hider)"

		local eRem = getRemain("SeekerSurge")
		seekerSurgeHint.Text = if eRem > 0
			then string.format("[E] Speed Surge (⏳ %ds)", eRem)
			else "[E] Speed Surge (วิ่งไวไล่ล่า 4s)"
	end
end)

--------------------------------------------------------------------------------
-- 4. KILL FEED (Top-Right) & LAST MAN STANDING BANNER + SOUND
--------------------------------------------------------------------------------
local killFeedContainer = Instance.new("Frame")
killFeedContainer.Name = "KillFeedContainer"
killFeedContainer.Size = UDim2.new(0, 310, 0, 180)
killFeedContainer.Position = UDim2.new(1, -20, 0, 20)
killFeedContainer.AnchorPoint = Vector2.new(1, 0)
killFeedContainer.BackgroundTransparency = 1
killFeedContainer.ZIndex = 25
killFeedContainer.Parent = screenGui

local killFeedLayout = Instance.new("UIListLayout")
killFeedLayout.Padding = UDim.new(0, 6)
killFeedLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
killFeedLayout.VerticalAlignment = Enum.VerticalAlignment.Top
killFeedLayout.SortOrder = Enum.SortOrder.LayoutOrder
killFeedLayout.Parent = killFeedContainer

local lmsBanner = Instance.new("Frame")
lmsBanner.Name = "LastManStandingBanner"
lmsBanner.Size = UDim2.new(0, 440, 0, 58)
lmsBanner.Position = UDim2.new(0.5, 0, 0, 96)
lmsBanner.AnchorPoint = Vector2.new(0.5, 0)
lmsBanner.Visible = false
lmsBanner.ZIndex = 30
stylePanel(lmsBanner, 12, Color3.fromRGB(255, 195, 55))
lmsBanner.Parent = screenGui

local lmsTitle = Instance.new("TextLabel")
lmsTitle.Size = UDim2.new(1, -20, 1, 0)
lmsTitle.Position = UDim2.fromScale(0.5, 0.5)
lmsTitle.AnchorPoint = Vector2.new(0.5, 0.5)
lmsTitle.BackgroundTransparency = 1
lmsTitle.Font = Enum.Font.GothamBlack
lmsTitle.TextSize = 17
lmsTitle.TextWrapped = true
lmsTitle.TextColor3 = Color3.fromRGB(255, 215, 70)
lmsTitle.Text = "⚠️ เหลือผู้ซ่อนคนสุดท้าย!"
lmsTitle.ZIndex = 31
lmsTitle.Parent = lmsBanner

local function pushKillFeedEntry(text: string, accentColor: Color3)
	local item = Instance.new("Frame")
	item.Size = UDim2.new(0, 300, 0, 32)
	item.ZIndex = 26
	stylePanel(item, 8, accentColor)
	item.Parent = killFeedContainer

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, -16, 1, 0)
	lbl.Position = UDim2.new(0, 8, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.GothamBold
	lbl.TextSize = 12
	lbl.TextXAlignment = Enum.TextXAlignment.Right
	lbl.TextTruncate = Enum.TextTruncate.AtEnd
	lbl.TextColor3 = Color3.fromRGB(245, 245, 255)
	lbl.Text = text
	lbl.ZIndex = 27
	lbl.Parent = item

	task.delay(5.5, function()
		if item.Parent then
			TweenService:Create(item, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
			TweenService:Create(lbl, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()
			task.wait(0.38)
			if item.Parent then
				item:Destroy()
			end
		end
	end)
end

local function triggerLastManStandingAlert(hiderName: string)
	lmsTitle.Text = string.format("⚠️ LAST HIDER STANDING: %s!", hiderName)
	lmsBanner.Visible = true
	lmsBanner.BackgroundTransparency = 0.08

	local alertSound = Instance.new("Sound")
	alertSound.Name = "LastManStandingSound"
	alertSound.SoundId = "rbxassetid://9119713951"
	alertSound.Volume = 1.0
	alertSound.PlaybackSpeed = 0.85
	alertSound.Parent = screenGui
	alertSound:Play()
	Debris:AddItem(alertSound, 4)

	task.delay(4.5, function()
		lmsBanner.Visible = false
	end)
end

roundEventNotice.OnClientEvent:Connect(function(eventType: string, payload: { [string]: any }?)
	if eventType == "KillFeed" and typeof(payload) == "table" then
		local killer = tostring(payload.Killer or "Seeker")
		local victim = tostring(payload.Victim or "Hider")
		local propName = tostring(payload.PropName or "Prop")
		if payload.Reason == "SelfEliminated" then
			pushKillFeedEntry(
				string.format("💥 %s ตีของจริงพลาดจนตัวเองตาย!", victim),
				Color3.fromRGB(255, 175, 65)
			)
		else
			pushKillFeedEntry(
				string.format("⚔️ %s จัดการ %s (%s)", killer, victim, propName),
				Color3.fromRGB(255, 85, 85)
			)
		end
	elseif eventType == "LastManStanding" and typeof(payload) == "table" then
		local hiderName = tostring(payload.HiderName or "Hider")
		triggerLastManStandingAlert(hiderName)
		pushKillFeedEntry(
			string.format("🔥 เหลือ Hider คนสุดท้าย: %s!", hiderName),
			Color3.fromRGB(255, 215, 70)
		)
	elseif eventType == "AbilityCooldown" and typeof(payload) == "table" then
		local ability = tostring(payload.Ability or "")
		local duration = tonumber(payload.Duration) or 0
		if ability ~= "" and duration > 0 then
			cooldownExpiries[ability] = os.clock() + duration
		end
	end
end)

--------------------------------------------------------------------------------
-- 5. ROUND SUMMARY / MVP CARD (Shown during RoundOver Phase)
--------------------------------------------------------------------------------
local summaryCard = Instance.new("Frame")
summaryCard.Name = "RoundSummaryMvpCard"
summaryCard.Size = UDim2.new(0, 420, 0, 215)
summaryCard.Position = UDim2.fromScale(0.5, 0.46)
summaryCard.AnchorPoint = Vector2.new(0.5, 0.5)
summaryCard.Visible = false
summaryCard.ZIndex = 35
stylePanel(summaryCard, 16, Color3.fromRGB(255, 215, 70))
summaryCard.Parent = screenGui

local summaryWinnerLabel = Instance.new("TextLabel")
summaryWinnerLabel.Size = UDim2.new(1, -24, 0, 36)
summaryWinnerLabel.Position = UDim2.new(0, 12, 0, 14)
summaryWinnerLabel.BackgroundTransparency = 1
summaryWinnerLabel.Font = Enum.Font.GothamBlack
summaryWinnerLabel.TextSize = 22
summaryWinnerLabel.TextColor3 = Color3.fromRGB(255, 215, 75)
summaryWinnerLabel.Text = "🏆 HIDERS WIN!"
summaryWinnerLabel.ZIndex = 36
summaryWinnerLabel.Parent = summaryCard

local summarySubLabel = Instance.new("TextLabel")
summarySubLabel.Size = UDim2.new(1, -24, 0, 22)
summarySubLabel.Position = UDim2.new(0, 12, 0, 50)
summarySubLabel.BackgroundTransparency = 1
summarySubLabel.Font = Enum.Font.GothamBold
summarySubLabel.TextSize = 14
summarySubLabel.TextColor3 = Color3.fromRGB(115, 245, 145)
summarySubLabel.Text = "ทีมที่ชนะได้รับ +50 Coins & +1 Win"
summarySubLabel.ZIndex = 36
summarySubLabel.Parent = summaryCard

local mvpHiderLabel = Instance.new("TextLabel")
mvpHiderLabel.Size = UDim2.new(1, -32, 0, 42)
mvpHiderLabel.Position = UDim2.new(0, 16, 0, 86)
mvpHiderLabel.BackgroundColor3 = Color3.fromRGB(28, 34, 48)
mvpHiderLabel.Font = Enum.Font.GothamBold
mvpHiderLabel.TextSize = 14
mvpHiderLabel.TextColor3 = Color3.fromRGB(110, 205, 255)
mvpHiderLabel.Text = "🥇 ซ่อนรอดนานสุด: -"
mvpHiderLabel.ZIndex = 36
mvpHiderLabel.Parent = summaryCard

local mvpCorner1 = Instance.new("UICorner")
mvpCorner1.CornerRadius = UDim.new(0, 8)
mvpCorner1.Parent = mvpHiderLabel

local mvpSeekerLabel = Instance.new("TextLabel")
mvpSeekerLabel.Size = UDim2.new(1, -32, 0, 42)
mvpSeekerLabel.Position = UDim2.new(0, 16, 0, 138)
mvpSeekerLabel.BackgroundColor3 = Color3.fromRGB(28, 34, 48)
mvpSeekerLabel.Font = Enum.Font.GothamBold
mvpSeekerLabel.TextSize = 14
mvpSeekerLabel.TextColor3 = Color3.fromRGB(255, 115, 115)
mvpSeekerLabel.Text = "⚔️ มือปราบ Seeker: -"
mvpSeekerLabel.ZIndex = 36
mvpSeekerLabel.Parent = summaryCard

local mvpCorner2 = Instance.new("UICorner")
mvpCorner2.CornerRadius = UDim.new(0, 8)
mvpCorner2.Parent = mvpSeekerLabel

roundEventNotice.OnClientEvent:Connect(function(eventType: string, payload: { [string]: any }?)
	if eventType == "RoundSummary" and typeof(payload) == "table" then
		local winningSide = tostring(payload.WinningSide or "Hiders")
		local bestHider = tostring(payload.BestHiderName or "-")
		local bestTime = tonumber(payload.BestHiderSurvival) or 0
		local bestSeeker = tostring(payload.BestSeekerName or "-")
		local bestKills = tonumber(payload.BestSeekerKills) or 0

		summaryWinnerLabel.Text = if winningSide == "Seekers"
			then "🏆 SEEKERS WIN! (ฝ่ายหาชนะ)"
			else "🏆 HIDERS WIN! (ฝ่ายซ่อนชนะ)"
		summaryWinnerLabel.TextColor3 = if winningSide == "Seekers"
			then Color3.fromRGB(255, 95, 95)
			else Color3.fromRGB(85, 205, 255)

		mvpHiderLabel.Text = string.format("🥇 ซ่อนรอดนานสุด: %s (%ds)", bestHider, bestTime)
		mvpSeekerLabel.Text = string.format("⚔️ มือปราบ Seeker: %s (%d Kills)", bestSeeker, bestKills)
		summaryCard.Visible = true

		local winSound = Instance.new("Sound")
		winSound.SoundId = "rbxassetid://9114074147"
		winSound.Volume = 0.85
		winSound.PlaybackSpeed = 1.1
		winSound.Parent = screenGui
		winSound:Play()
		Debris:AddItem(winSound, 3)

		task.delay(4.8, function()
			summaryCard.Visible = false
		end)
	end
end)

--------------------------------------------------------------------------------
-- 6. AMBIENT BGM & LAST 30s TENSION AUDIO
--------------------------------------------------------------------------------
local bgmSound = Instance.new("Sound")
bgmSound.Name = "PhaseAmbientSound"
bgmSound.SoundId = "rbxassetid://9114074403"
bgmSound.Looped = false
bgmSound.Volume = 0.2
bgmSound.Parent = screenGui

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

	-- Tension tick in last 15 seconds of HuntingPhase
	if rawState == "HuntingPhase" and timerNum > 0 and timerNum <= 15 then
		timerLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
		bgmSound.SoundId = "rbxassetid://12222124"
		bgmSound.PlaybackSpeed = 1.9
		bgmSound.Volume = 0.25
		bgmSound:Play()
	else
		timerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	end

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

-- 2. Update Role Text & Hider/Seeker Controls Visibility
local function updateRoleAndControls()
	local teamName = if localPlayer.Team then localPlayer.Team.Name else "Lobby"
	local character = localPlayer.Character
	local isLocked = character and character:GetAttribute("IsPropLocked") == true
	local sizeClass = character and character:GetAttribute("PropSizeClass")

	if teamName == "Hiders" then
		local sizeSuffix = if typeof(sizeClass) == "string" then string.format(" (%s)", sizeClass) else ""
		roleLabel.Text = if isLocked
			then "ROLE: HIDER [LOCKED]" .. sizeSuffix
			else "ROLE: HIDER" .. sizeSuffix
		roleLabel.TextColor3 = ROLE_COLORS.Hiders
		hiderControlsFrame.Visible = true
		seekerControlsFrame.Visible = false

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
		seekerControlsFrame.Visible = true
	else
		roleLabel.Text = "ROLE: LOBBY"
		roleLabel.TextColor3 = ROLE_COLORS.Lobby
		hiderControlsFrame.Visible = false
		seekerControlsFrame.Visible = false
	end

	-- Keep silence warning unused variable checks
	local _ = morphHintLabel
	local _ = seekerAttackHint
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
	character:GetAttributeChangedSignal("PropSizeClass"):Connect(updateRoleAndControls)

	local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
	if humanoid then
		updateHealthBar(humanoid.Health, humanoid.MaxHealth)
		healthConnection = humanoid.HealthChanged:Connect(function(newHealth: number)
			updateHealthBar(newHealth, humanoid.MaxHealth)
		end)
		humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(function()
			updateHealthBar(humanoid.Health, humanoid.MaxHealth)
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
