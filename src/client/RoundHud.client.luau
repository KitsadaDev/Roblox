--!strict
-- StarterPlayerScripts/Client/RoundHud.client.luau
-- Modern Glassmorphic Game HUD:
-- 1. Top Status Pill (Phase Badge + Crisp MM:SS Countdown, auto-hidden when Lobby Dashboard is open)
-- 2. Bottom-Left Player Status Card (Color-coded Role + Live Coins Pill + Smooth Gradient Health Bar)
-- 3. Bottom-Right Tactical Keycap Controls Hints (Hiders & Seekers with live cooldown readouts)
-- 4. Animated Kill Feed, Last Man Standing Alert & Victory MVP Summary Modal

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui

local PropRemotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PropRemotes"))
local roundEventNotice = PropRemotes.RoundEventNotice

--------------------------------------------------------------------------------
-- UI STYLING HELPERS (Always ApplyStrokeMode.Border!)
--------------------------------------------------------------------------------
local PANEL_BG_COLOR = Color3.fromRGB(16, 20, 32)
local PANEL_STROKE_COLOR = Color3.fromRGB(72, 92, 132)

local ROLE_COLORS = {
	Lobby = Color3.fromRGB(190, 205, 230),
	Hiders = Color3.fromRGB(75, 195, 255),
	Seekers = Color3.fromRGB(255, 90, 98),
}

type MapHudTheme = {
	Badge: string,
	Title: string,
	Sub: string,
	Accent: Color3,
	GradA: Color3,
	GradB: Color3,
}

local MAP_HUD_THEMES: { [string]: MapHudTheme } = {
	GrandPlaza = {
		Badge = "🏢 GRAND PLAZA • ออฟฟิศ & อาร์เคด",
		Title = "GRAND PLAZA",
		Sub = "อาคารสำนักงาน • ห้องสมุด • โกดังสินค้า • โซนตู้เกมอาร์เคด",
		Accent = Color3.fromRGB(85, 195, 255),
		GradA = Color3.fromRGB(24, 52, 92),
		GradB = Color3.fromRGB(14, 24, 44),
	},
	CyberpunkMall = {
		Badge = "🌆 CYBERPUNK MALL • ห้างไซเบอร์นีออน",
		Title = "CYBERPUNK NEON MALL",
		Sub = "ห้องเซิร์ฟเวอร์ • โถงคริสตัลโฮโลแกรม • ตลาดไซเบอร์",
		Accent = Color3.fromRGB(235, 80, 225),
		GradA = Color3.fromRGB(68, 22, 88),
		GradB = Color3.fromRGB(18, 18, 48),
	},
	SchoolCampus = {
		Badge = "🏫 HIGH SCHOOL • โรงเรียนมัธยม",
		Title = "HIGH SCHOOL CAMPUS",
		Sub = "ห้องเรียน • ห้องสมุด & ล็อกเกอร์ • โรงอาหาร • โรงยิมบาสเกตบอล",
		Accent = Color3.fromRGB(255, 190, 72),
		GradA = Color3.fromRGB(82, 54, 24),
		GradB = Color3.fromRGB(28, 24, 34),
	},
	CampingPark = {
		Badge = "🏕️ CAMPING PARK • แคมป์ปิ้งยามเย็น",
		Title = "SUNSET CAMPING PARK",
		Sub = "ลานกางเต็นท์ป่าสน • สะพานลำธาร • ลานกองไฟ • ป้อมเจ้าหน้าที่",
		Accent = Color3.fromRGB(92, 225, 130),
		GradA = Color3.fromRGB(24, 68, 44),
		GradB = Color3.fromRGB(16, 28, 26),
	},
	JapaneseVillage = {
		Badge = "⛩️ SAKURA VILLAGE • หมู่บ้านซากุระ",
		Title = "SAKURA JAPANESE VILLAGE",
		Sub = "สะพานแดงสระปลาคราฟ • โรงน้ำชา • ถนนร้านราเมง • สวนหินเซน",
		Accent = Color3.fromRGB(255, 138, 188),
		GradA = Color3.fromRGB(82, 28, 56),
		GradB = Color3.fromRGB(26, 18, 34),
	},
	MedievalCastle = {
		Badge = "🏰 MEDIEVAL CASTLE • ปราสาทยุคกลาง",
		Title = "ROYAL MEDIEVAL CASTLE",
		Sub = "ลานดาบปักหิน • โถงจัดเลี้ยงราชา • หอสมุดเวทมนตร์ • โรงตีเหล็ก",
		Accent = Color3.fromRGB(255, 120, 95),
		GradA = Color3.fromRGB(78, 26, 32),
		GradB = Color3.fromRGB(24, 18, 28),
	},
}

local function addCorner(inst: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = inst
end

local function addBorderStroke(inst: Instance, color: Color3, thickness: number, transparency: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Color = color
	s.Thickness = thickness
	s.Transparency = transparency or 0.25
	s.Parent = inst
	return s
end

local function addGradient(inst: Instance, c0: Color3, c1: Color3, rot: number?): UIGradient
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(c0, c1)
	g.Rotation = rot or 90
	g.Parent = inst
	return g
end

local function stylePanel(frame: Frame, cornerRadius: number, strokeColor: Color3?): UIStroke
	frame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	frame.BackgroundTransparency = 0.08
	frame.BorderSizePixel = 0
	addCorner(frame, cornerRadius)
	addGradient(frame, Color3.fromRGB(26, 33, 52), Color3.fromRGB(14, 18, 30), 110)
	return addBorderStroke(frame, strokeColor or PANEL_STROKE_COLOR, 1.6, 0.25)
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
-- 1. TOP STATUS BAR (Top-Center: Phase Badge + MM:SS Countdown + Active Map Pill)
--------------------------------------------------------------------------------
local topBarFrame = Instance.new("Frame")
topBarFrame.Name = "TopStatusBar"
topBarFrame.Size = UDim2.fromOffset(356, 86)
topBarFrame.Position = UDim2.new(0.5, 0, 0, 12)
topBarFrame.AnchorPoint = Vector2.new(0.5, 0)
topBarFrame.ZIndex = 20
local topBarStroke = stylePanel(topBarFrame, 16)
topBarFrame.Parent = screenGui

local statePill = Instance.new("Frame")
statePill.Size = UDim2.new(1, -24, 0, 21)
statePill.Position = UDim2.new(0.5, 0, 0, 6)
statePill.AnchorPoint = Vector2.new(0.5, 0)
statePill.BackgroundColor3 = Color3.fromRGB(26, 34, 54)
statePill.BorderSizePixel = 0
statePill.ZIndex = 21
statePill.Parent = topBarFrame
addCorner(statePill, 8)

local stateLabel = Instance.new("TextLabel")
stateLabel.Name = "StateLabel"
stateLabel.Size = UDim2.new(1, -12, 1, 0)
stateLabel.Position = UDim2.fromOffset(6, 0)
stateLabel.BackgroundTransparency = 1
stateLabel.Font = Enum.Font.GothamBlack
stateLabel.TextSize = 11
stateLabel.TextTruncate = Enum.TextTruncate.AtEnd
stateLabel.TextColor3 = Color3.fromRGB(185, 205, 235)
stateLabel.Text = "🟢 รอผู้เล่นพร้อมเริ่มเกม"
stateLabel.ZIndex = 22
stateLabel.Parent = statePill

local timerLabel = Instance.new("TextLabel")
timerLabel.Name = "TimerLabel"
timerLabel.Size = UDim2.new(1, -24, 0, 30)
timerLabel.Position = UDim2.new(0.5, 0, 0, 29)
timerLabel.AnchorPoint = Vector2.new(0.5, 0)
timerLabel.BackgroundTransparency = 1
timerLabel.Font = Enum.Font.GothamBlack
timerLabel.TextSize = 25
timerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
timerLabel.Text = "00:00"
timerLabel.ZIndex = 21
timerLabel.Parent = topBarFrame

local mapLocationLabel = Instance.new("TextLabel")
mapLocationLabel.Name = "MapLocationLabel"
mapLocationLabel.Size = UDim2.new(1, -24, 0, 18)
mapLocationLabel.Position = UDim2.new(0.5, 0, 1, -22)
mapLocationLabel.AnchorPoint = Vector2.new(0.5, 0)
mapLocationLabel.BackgroundTransparency = 1
mapLocationLabel.Font = Enum.Font.GothamBold
mapLocationLabel.TextSize = 11
mapLocationLabel.TextTruncate = Enum.TextTruncate.AtEnd
mapLocationLabel.TextColor3 = Color3.fromRGB(145, 210, 255)
mapLocationLabel.Text = "🏢 GRAND PLAZA • ออฟฟิศ & อาร์เคด"
mapLocationLabel.ZIndex = 21
mapLocationLabel.Parent = topBarFrame

-- Cinematic Map Arrival Intro Card (Glides in smoothly when entering any map!)
local mapIntroCard = Instance.new("Frame")
mapIntroCard.Name = "CinematicMapIntro"
mapIntroCard.Size = UDim2.fromOffset(460, 88)
mapIntroCard.Position = UDim2.new(0.5, 0, 0, 108)
mapIntroCard.AnchorPoint = Vector2.new(0.5, 0)
mapIntroCard.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
mapIntroCard.BackgroundTransparency = 1
mapIntroCard.BorderSizePixel = 0
mapIntroCard.Visible = false
mapIntroCard.ZIndex = 29
mapIntroCard.Parent = screenGui
addCorner(mapIntroCard, 16)
local introStroke = addBorderStroke(mapIntroCard, Color3.fromRGB(85, 195, 255), 1.6, 1)
local introGrad = addGradient(mapIntroCard, Color3.fromRGB(24, 52, 92), Color3.fromRGB(14, 24, 44), 115)

local introTagLbl = Instance.new("TextLabel")
introTagLbl.Size = UDim2.new(1, -24, 0, 16)
introTagLbl.Position = UDim2.fromOffset(12, 10)
introTagLbl.BackgroundTransparency = 1
introTagLbl.Font = Enum.Font.GothamBlack
introTagLbl.TextSize = 10
introTagLbl.TextColor3 = Color3.fromRGB(255, 220, 95)
introTagLbl.TextTransparency = 1
introTagLbl.Text = "★ NOW ENTERING ARENA • พื้นที่การแข่งขัน ★"
introTagLbl.ZIndex = 30
introTagLbl.Parent = mapIntroCard

local introTitleLbl = Instance.new("TextLabel")
introTitleLbl.Size = UDim2.new(1, -24, 0, 28)
introTitleLbl.Position = UDim2.fromOffset(12, 28)
introTitleLbl.BackgroundTransparency = 1
introTitleLbl.Font = Enum.Font.GothamBlack
introTitleLbl.TextSize = 20
introTitleLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
introTitleLbl.TextTransparency = 1
introTitleLbl.Text = "GRAND PLAZA"
introTitleLbl.ZIndex = 30
introTitleLbl.Parent = mapIntroCard

local introSubLbl = Instance.new("TextLabel")
introSubLbl.Size = UDim2.new(1, -24, 0, 18)
introSubLbl.Position = UDim2.fromOffset(12, 58)
introSubLbl.BackgroundTransparency = 1
introSubLbl.Font = Enum.Font.GothamMedium
introSubLbl.TextSize = 12
introSubLbl.TextColor3 = Color3.fromRGB(185, 205, 235)
introSubLbl.TextTransparency = 1
introSubLbl.Text = ""
introSubLbl.ZIndex = 30
introSubLbl.Parent = mapIntroCard

--------------------------------------------------------------------------------
-- 2. ROLE, COINS & HEALTH INDICATOR (Bottom-Left)
--------------------------------------------------------------------------------
local roleHealthFrame = Instance.new("Frame")
roleHealthFrame.Name = "RoleHealthIndicator"
roleHealthFrame.Size = UDim2.fromOffset(286, 84)
roleHealthFrame.Position = UDim2.new(0, 20, 1, -20)
roleHealthFrame.AnchorPoint = Vector2.new(0, 1)
roleHealthFrame.ZIndex = 20
local roleCardStroke = stylePanel(roleHealthFrame, 16)
roleHealthFrame.Parent = screenGui

local roleLabel = Instance.new("TextLabel")
roleLabel.Name = "RoleLabel"
roleLabel.Size = UDim2.new(1, -110, 0, 26)
roleLabel.Position = UDim2.fromOffset(14, 10)
roleLabel.BackgroundTransparency = 1
roleLabel.Font = Enum.Font.GothamBlack
roleLabel.TextSize = 15
roleLabel.TextXAlignment = Enum.TextXAlignment.Left
roleLabel.TextTruncate = Enum.TextTruncate.AtEnd
roleLabel.TextColor3 = ROLE_COLORS.Lobby
roleLabel.Text = "🏠 LOBBY"
roleLabel.ZIndex = 21
roleLabel.Parent = roleHealthFrame

local hudCoinsBadge = Instance.new("TextLabel")
hudCoinsBadge.Size = UDim2.fromOffset(82, 24)
hudCoinsBadge.Position = UDim2.new(1, -14, 0, 11)
hudCoinsBadge.AnchorPoint = Vector2.new(1, 0)
hudCoinsBadge.BackgroundColor3 = Color3.fromRGB(36, 32, 20)
hudCoinsBadge.Font = Enum.Font.GothamBlack
hudCoinsBadge.TextSize = 12
hudCoinsBadge.TextColor3 = Color3.fromRGB(255, 220, 75)
hudCoinsBadge.Text = "💰 0 C"
hudCoinsBadge.ZIndex = 21
hudCoinsBadge.Parent = roleHealthFrame
addCorner(hudCoinsBadge, 8)
addBorderStroke(hudCoinsBadge, Color3.fromRGB(255, 205, 65), 1.2, 0.35)

local healthBarBg = Instance.new("Frame")
healthBarBg.Name = "HealthBarBackground"
healthBarBg.Size = UDim2.new(1, -28, 0, 24)
healthBarBg.Position = UDim2.fromOffset(14, 46)
healthBarBg.BackgroundColor3 = Color3.fromRGB(12, 16, 26)
healthBarBg.BorderSizePixel = 0
healthBarBg.ZIndex = 21
healthBarBg.Parent = roleHealthFrame
addCorner(healthBarBg, 8)
addBorderStroke(healthBarBg, Color3.fromRGB(52, 66, 95), 1, 0.45)

local healthBarFill = Instance.new("Frame")
healthBarFill.Name = "HealthBarFill"
healthBarFill.Size = UDim2.fromScale(1, 1)
healthBarFill.BackgroundColor3 = Color3.fromRGB(65, 220, 115)
healthBarFill.BorderSizePixel = 0
healthBarFill.ZIndex = 22
healthBarFill.Parent = healthBarBg
addCorner(healthBarFill, 8)
local hpGrad = addGradient(healthBarFill, Color3.fromRGB(95, 245, 140), Color3.fromRGB(36, 175, 86), 90)

local healthValueLabel = Instance.new("TextLabel")
healthValueLabel.Name = "HealthValueLabel"
healthValueLabel.Size = UDim2.fromScale(1, 1)
healthValueLabel.BackgroundTransparency = 1
healthValueLabel.Font = Enum.Font.GothamBlack
healthValueLabel.TextSize = 12
healthValueLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
healthValueLabel.TextStrokeTransparency = 0.55
healthValueLabel.Text = "❤️ 100 / 100 HP"
healthValueLabel.ZIndex = 23
healthValueLabel.Parent = healthBarBg

--------------------------------------------------------------------------------
-- 3. HIDER & SEEKER TACTICAL CONTROLS HINT (Bottom-Right)
--------------------------------------------------------------------------------
local function createKeyRow(parent: Frame, yOffset: number, keyText: string, descText: string, keyCol: Color3): (TextLabel, TextLabel)
	local keyCap = Instance.new("TextLabel")
	keyCap.Size = UDim2.fromOffset(58, 20)
	keyCap.Position = UDim2.fromOffset(12, yOffset)
	keyCap.BackgroundColor3 = Color3.fromRGB(26, 34, 52)
	keyCap.Font = Enum.Font.GothamBlack
	keyCap.TextSize = 11
	keyCap.TextColor3 = keyCol
	keyCap.Text = keyText
	keyCap.ZIndex = 22
	keyCap.Parent = parent
	addCorner(keyCap, 6)
	addBorderStroke(keyCap, keyCol, 1, 0.45)

	local desc = Instance.new("TextLabel")
	desc.Size = UDim2.new(1, -84, 0, 20)
	desc.Position = UDim2.fromOffset(76, yOffset)
	desc.BackgroundTransparency = 1
	desc.Font = Enum.Font.GothamMedium
	desc.TextSize = 12
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.TextTruncate = Enum.TextTruncate.AtEnd
	desc.TextColor3 = Color3.fromRGB(225, 234, 250)
	desc.Text = descText
	desc.ZIndex = 22
	desc.Parent = parent

	return keyCap, desc
end

local hiderControlsFrame = Instance.new("Frame")
hiderControlsFrame.Name = "HiderControlsHint"
hiderControlsFrame.Size = UDim2.fromOffset(296, 168)
hiderControlsFrame.Position = UDim2.new(1, -20, 1, -20)
hiderControlsFrame.AnchorPoint = Vector2.new(1, 1)
hiderControlsFrame.Visible = false
hiderControlsFrame.ZIndex = 20
stylePanel(hiderControlsFrame, 16, Color3.fromRGB(75, 195, 255))
hiderControlsFrame.Parent = screenGui

local controlsHeader = Instance.new("TextLabel")
controlsHeader.Size = UDim2.new(1, -24, 0, 22)
controlsHeader.Position = UDim2.fromOffset(12, 8)
controlsHeader.BackgroundTransparency = 1
controlsHeader.Font = Enum.Font.GothamBlack
controlsHeader.TextSize = 13
controlsHeader.TextXAlignment = Enum.TextXAlignment.Left
controlsHeader.TextColor3 = Color3.fromRGB(85, 205, 255)
controlsHeader.Text = "🟦 สกิลและการควบคุมฝ่ายซ่อน (HIDER)"
controlsHeader.ZIndex = 21
controlsHeader.Parent = hiderControlsFrame

local hCol = Color3.fromRGB(85, 205, 255)
local _, _morphDesc = createKeyRow(hiderControlsFrame, 36, "Click / E", "แปลงร่างเป็นสิ่งของ", hCol)
local _, lockHintDesc = createKeyRow(hiderControlsFrame, 61, "F  |  R", "ล็อกตัวนิ่ง • หมุน 45°", hCol)
local _, tauntHintDesc = createKeyRow(hiderControlsFrame, 86, "T", "ผิวปากล่อ (+5~20 Coins)", Color3.fromRGB(255, 215, 75))
local _, decoyHintDesc = createKeyRow(hiderControlsFrame, 111, "G", "วางร่างปลอมหลอก (20 C)", hCol)
local _, sprintHintDesc = createKeyRow(hiderControlsFrame, 136, "Shift", "ระเบิดควันวิ่งหนี", hCol)

-- Seeker Controls Hint Frame
local seekerControlsFrame = Instance.new("Frame")
seekerControlsFrame.Name = "SeekerControlsHint"
seekerControlsFrame.Size = UDim2.fromOffset(296, 120)
seekerControlsFrame.Position = UDim2.new(1, -20, 1, -20)
seekerControlsFrame.AnchorPoint = Vector2.new(1, 1)
seekerControlsFrame.Visible = false
seekerControlsFrame.ZIndex = 20
stylePanel(seekerControlsFrame, 16, Color3.fromRGB(255, 90, 98))
seekerControlsFrame.Parent = screenGui

local seekerControlsHeader = Instance.new("TextLabel")
seekerControlsHeader.Size = UDim2.new(1, -24, 0, 22)
seekerControlsHeader.Position = UDim2.fromOffset(12, 8)
seekerControlsHeader.BackgroundTransparency = 1
seekerControlsHeader.Font = Enum.Font.GothamBlack
seekerControlsHeader.TextSize = 13
seekerControlsHeader.TextXAlignment = Enum.TextXAlignment.Left
seekerControlsHeader.TextColor3 = Color3.fromRGB(255, 105, 110)
seekerControlsHeader.Text = "🟥 สกิลและการควบคุมฝ่ายหา (SEEKER)"
seekerControlsHeader.ZIndex = 21
seekerControlsHeader.Parent = seekerControlsFrame

local sCol = Color3.fromRGB(255, 105, 110)
local _, _attackDesc = createKeyRow(seekerControlsFrame, 36, "Click", "ยิงตรวจจับ (พลาด -15 HP)", sCol)
local _, seekerRadarDesc = createKeyRow(seekerControlsFrame, 62, "Q", "เรดาร์สแกนระยะ Hider", Color3.fromRGB(255, 215, 75))
local _, seekerSurgeDesc = createKeyRow(seekerControlsFrame, 88, "E", "เร่งสปีดวิ่งไล่ล่า 4 วินาที", sCol)

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
		tauntHintDesc.Text = if tRem > 0 then string.format("⏳ คูลดาวน์ผิวปาก (%ds)", tRem) else "ผิวปากล่อ (+5~20 Coins)"
		tauntHintDesc.TextColor3 = if tRem > 0 then Color3.fromRGB(255, 185, 85) else Color3.fromRGB(225, 234, 250)

		local dRem = getRemain("SpawnDecoy")
		decoyHintDesc.Text = if dRem > 0 then string.format("⏳ คูลดาวน์ร่างปลอม (%ds)", dRem) else "วางร่างปลอมหลอก (20 C)"
		decoyHintDesc.TextColor3 = if dRem > 0 then Color3.fromRGB(255, 185, 85) else Color3.fromRGB(225, 234, 250)

		local sRem = getRemain("SmokeSprint")
		sprintHintDesc.Text = if sRem > 0 then string.format("⏳ คูลดาวน์วิ่งหนี (%ds)", sRem) else "ระเบิดควันวิ่งหนี"
		sprintHintDesc.TextColor3 = if sRem > 0 then Color3.fromRGB(255, 185, 85) else Color3.fromRGB(225, 234, 250)

		local rRem = getRemain("SeekerRadar")
		seekerRadarDesc.Text = if rRem > 0 then string.format("⏳ คูลดาวน์เรดาร์ (%ds)", rRem) else "เรดาร์สแกนระยะ Hider"
		seekerRadarDesc.TextColor3 = if rRem > 0 then Color3.fromRGB(255, 185, 85) else Color3.fromRGB(225, 234, 250)

		local eRem = getRemain("SeekerSurge")
		seekerSurgeDesc.Text = if eRem > 0 then string.format("⏳ คูลดาวน์เร่งสปีด (%ds)", eRem) else "เร่งสปีดวิ่งไล่ล่า 4 วินาที"
		seekerSurgeDesc.TextColor3 = if eRem > 0 then Color3.fromRGB(255, 185, 85) else Color3.fromRGB(225, 234, 250)
	end
end)

--------------------------------------------------------------------------------
-- 4. KILL FEED (Top-Right), SEEKER FINAL 30s HINT CARD (Top-Left) & LMS BANNER
--------------------------------------------------------------------------------
local seekerHintCard = Instance.new("Frame")
seekerHintCard.Name = "SeekerFinalHintCard"
seekerHintCard.Size = UDim2.fromOffset(316, 118)
seekerHintCard.Position = UDim2.fromOffset(20, 68)
seekerHintCard.Visible = false
seekerHintCard.ZIndex = 24
stylePanel(seekerHintCard, 16, Color3.fromRGB(255, 205, 70))
seekerHintCard.Parent = screenGui

local seekerHintHeader = Instance.new("TextLabel")
seekerHintHeader.Size = UDim2.new(1, -24, 0, 22)
seekerHintHeader.Position = UDim2.fromOffset(12, 8)
seekerHintHeader.BackgroundTransparency = 1
seekerHintHeader.Font = Enum.Font.GothamBlack
seekerHintHeader.TextSize = 13
seekerHintHeader.TextXAlignment = Enum.TextXAlignment.Left
seekerHintHeader.TextColor3 = Color3.fromRGB(255, 218, 75)
seekerHintHeader.Text = "💡 คำใบ้ 30 วิสุดท้าย!"
seekerHintHeader.ZIndex = 25
seekerHintHeader.Parent = seekerHintCard

local seekerHintSub = Instance.new("TextLabel")
seekerHintSub.Size = UDim2.new(1, -24, 0, 16)
seekerHintSub.Position = UDim2.fromOffset(12, 29)
seekerHintSub.BackgroundTransparency = 1
seekerHintSub.Font = Enum.Font.GothamMedium
seekerHintSub.TextSize = 11
seekerHintSub.TextXAlignment = Enum.TextXAlignment.Left
seekerHintSub.TextColor3 = Color3.fromRGB(175, 195, 228)
seekerHintSub.Text = "เบาะแสบริเวณคร่าวๆ ของผู้ซ่อนที่เหลือ:"
seekerHintSub.ZIndex = 25
seekerHintSub.Parent = seekerHintCard

local seekerHintList = Instance.new("Frame")
seekerHintList.Size = UDim2.new(1, -24, 1, -54)
seekerHintList.Position = UDim2.fromOffset(12, 48)
seekerHintList.BackgroundTransparency = 1
seekerHintList.ZIndex = 25
seekerHintList.Parent = seekerHintCard

local seekerHintLayout = Instance.new("UIListLayout")
seekerHintLayout.Padding = UDim.new(0, 4)
seekerHintLayout.SortOrder = Enum.SortOrder.LayoutOrder
seekerHintLayout.Parent = seekerHintList

local activeHintVisuals: { Instance } = {}

local function clearSeekerHintVisuals()
	for _, inst in activeHintVisuals do
		if inst.Parent then
			inst:Destroy()
		end
	end
	table.clear(activeHintVisuals)
end

local function spawnApproximateHintZoneVfx(approxPos: Vector3, zoneText: string)
	-- Wide 28-stud translucent floor ring (offset on server so Hider is never dead-center!)
	local zoneDisc = Instance.new("Part")
	zoneDisc.Name = "SeekerHintSearchZone"
	zoneDisc.Shape = Enum.PartType.Cylinder
	zoneDisc.Anchored = true
	zoneDisc.CanCollide = false
	zoneDisc.CanQuery = false
	zoneDisc.CastShadow = false
	zoneDisc.Material = Enum.Material.Neon
	zoneDisc.Color = Color3.fromRGB(255, 205, 75)
	zoneDisc.Transparency = 0.78
	zoneDisc.Size = Vector3.new(0.18, 28, 28)
	zoneDisc.CFrame = CFrame.new(approxPos) * CFrame.Angles(0, 0, math.rad(90))
	zoneDisc.Parent = workspace
	table.insert(activeHintVisuals, zoneDisc)

	-- Floating "?" Area Beacon visible through partition walls briefly (5.5s)
	local beaconAnchor = Instance.new("Part")
	beaconAnchor.Name = "SeekerHintBeacon"
	beaconAnchor.Anchored = true
	beaconAnchor.CanCollide = false
	beaconAnchor.CanQuery = false
	beaconAnchor.Transparency = 1
	beaconAnchor.Size = Vector3.new(1, 1, 1)
	beaconAnchor.Position = approxPos + Vector3.new(0, 5.5, 0)
	beaconAnchor.Parent = workspace
	table.insert(activeHintVisuals, beaconAnchor)

	local bGui = Instance.new("BillboardGui")
	bGui.Size = UDim2.fromOffset(168, 42)
	bGui.AlwaysOnTop = true
	bGui.MaxDistance = 280
	bGui.Parent = beaconAnchor

	local pill = Instance.new("Frame")
	pill.Size = UDim2.fromScale(1, 1)
	pill.BackgroundColor3 = Color3.fromRGB(20, 24, 36)
	pill.BackgroundTransparency = 0.12
	pill.BorderSizePixel = 0
	pill.Parent = bGui
	addCorner(pill, 10)
	local pillStroke = addBorderStroke(pill, Color3.fromRGB(255, 210, 75), 1.6, 0.15)

	local txt = Instance.new("TextLabel")
	txt.Size = UDim2.new(1, -12, 1, 0)
	txt.Position = UDim2.fromOffset(6, 0)
	txt.BackgroundTransparency = 1
	txt.Font = Enum.Font.GothamBlack
	txt.TextSize = 12
	txt.TextWrapped = true
	txt.TextColor3 = Color3.fromRGB(255, 225, 95)
	txt.Text = "❓ โซนต้องสงสัย\n" .. zoneText
	txt.Parent = pill

	TweenService:Create(
		zoneDisc,
		TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 3, true),
		{ Transparency = 0.58, Size = Vector3.new(0.18, 31, 31) }
	):Play()

	task.delay(5.0, function()
		if zoneDisc.Parent then
			TweenService:Create(zoneDisc, TweenInfo.new(0.6), { Transparency = 1 }):Play()
		end
		if pill.Parent then
			TweenService:Create(pill, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
			TweenService:Create(txt, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
			TweenService:Create(pillStroke, TweenInfo.new(0.6), { Transparency = 1 }):Play()
		end
	end)

	Debris:AddItem(zoneDisc, 5.8)
	Debris:AddItem(beaconAnchor, 5.8)
end
local killFeedContainer = Instance.new("Frame")
killFeedContainer.Name = "KillFeedContainer"
killFeedContainer.Size = UDim2.fromOffset(320, 180)
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
lmsBanner.Size = UDim2.fromOffset(440, 56)
lmsBanner.Position = UDim2.new(0.5, 0, 0, 92)
lmsBanner.AnchorPoint = Vector2.new(0.5, 0)
lmsBanner.Visible = false
lmsBanner.ZIndex = 30
stylePanel(lmsBanner, 14, Color3.fromRGB(255, 200, 55))
lmsBanner.Parent = screenGui

local lmsTitle = Instance.new("TextLabel")
lmsTitle.Size = UDim2.new(1, -24, 1, 0)
lmsTitle.Position = UDim2.fromScale(0.5, 0.5)
lmsTitle.AnchorPoint = Vector2.new(0.5, 0.5)
lmsTitle.BackgroundTransparency = 1
lmsTitle.Font = Enum.Font.GothamBlack
lmsTitle.TextSize = 16
lmsTitle.TextWrapped = true
lmsTitle.TextColor3 = Color3.fromRGB(255, 220, 75)
lmsTitle.Text = "⚠️ เหลือผู้ซ่อนคนสุดท้าย!"
lmsTitle.ZIndex = 31
lmsTitle.Parent = lmsBanner

local function pushKillFeedEntry(text: string, accentColor: Color3)
	local item = Instance.new("Frame")
	item.Size = UDim2.fromOffset(308, 34)
	item.ZIndex = 26
	stylePanel(item, 10, accentColor)
	item.Parent = killFeedContainer

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, -20, 1, 0)
	lbl.Position = UDim2.fromOffset(10, 0)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.GothamBold
	lbl.TextSize = 12
	lbl.TextXAlignment = Enum.TextXAlignment.Right
	lbl.TextTruncate = Enum.TextTruncate.AtEnd
	lbl.TextColor3 = Color3.fromRGB(245, 248, 255)
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
	lmsTitle.Text = string.format("🔥 เหลือผู้ซ่อนคนสุดท้าย: %s!", hiderName)
	lmsBanner.Visible = true
	lmsBanner.BackgroundTransparency = 0.06

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
				string.format("💥 %s ยิงของจริงพลาดจนตัวเองตาย!", victim),
				Color3.fromRGB(255, 175, 65)
			)
		else
			pushKillFeedEntry(
				string.format("⚔️ %s จัดการ %s (%s)", killer, victim, propName),
				Color3.fromRGB(255, 85, 95)
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
	elseif eventType == "SeekerFinalHint" and typeof(payload) == "table" then
		for _, ch in seekerHintList:GetChildren() do
			if ch:IsA("TextLabel") then
				ch:Destroy()
			end
		end
		clearSeekerHintVisuals()

		local titleStr = tostring(payload.Title or "คำใบ้ 30 วิสุดท้าย!")
		local aliveCount = tonumber(payload.AliveCount) or 1
		seekerHintHeader.Text = string.format("💡 %s (เหลือ %d คน)", titleStr, aliveCount)

		local clues = payload.Clues
		local rowCount = 0
		if typeof(clues) == "table" then
			for idx, line in clues do
				rowCount += 1
				local row = Instance.new("TextLabel")
				row.LayoutOrder = idx
				row.Size = UDim2.new(1, 0, 0, 22)
				row.BackgroundColor3 = Color3.fromRGB(24, 31, 48)
				row.Font = Enum.Font.GothamBold
				row.TextSize = 11
				row.TextXAlignment = Enum.TextXAlignment.Left
				row.TextTruncate = Enum.TextTruncate.AtEnd
				row.TextColor3 = Color3.fromRGB(245, 248, 255)
				row.Text = "  " .. tostring(line)
				row.ZIndex = 26
				row.Parent = seekerHintList
				addCorner(row, 6)
			end
		end

		seekerHintCard.Size = UDim2.fromOffset(324, 58 + math.max(1, rowCount) * 26)
		seekerHintCard.Visible = true

		local hintChime = Instance.new("Sound")
		hintChime.SoundId = "rbxassetid://12222124"
		hintChime.PlaybackSpeed = 1.55
		hintChime.Volume = 0.55
		hintChime.Parent = screenGui
		hintChime:Play()
		Debris:AddItem(hintChime, 2)

		local pings = payload.Pings
		if typeof(pings) == "table" then
			for _, ping in pings do
				if typeof(ping) == "table" and typeof(ping.Pos) == "Vector3" then
					spawnApproximateHintZoneVfx(ping.Pos, tostring(ping.Zone or ""))
				end
			end
		end
	end
end)

--------------------------------------------------------------------------------
-- 5. ROUND SUMMARY / MVP CARD (Shown during RoundOver Phase)
--------------------------------------------------------------------------------
local summaryCard = Instance.new("Frame")
summaryCard.Name = "RoundSummaryMvpCard"
summaryCard.Size = UDim2.fromOffset(450, 276)
summaryCard.Position = UDim2.fromScale(0.5, 0.48)
summaryCard.AnchorPoint = Vector2.new(0.5, 0.5)
summaryCard.Visible = false
summaryCard.ZIndex = 38
local summaryStroke = stylePanel(summaryCard, 20, Color3.fromRGB(255, 215, 75))
summaryCard.Parent = screenGui

local summaryHeaderBox = Instance.new("Frame")
summaryHeaderBox.Size = UDim2.new(1, -24, 0, 72)
summaryHeaderBox.Position = UDim2.fromOffset(12, 12)
summaryHeaderBox.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
summaryHeaderBox.BorderSizePixel = 0
summaryHeaderBox.ZIndex = 39
summaryHeaderBox.Parent = summaryCard
addCorner(summaryHeaderBox, 14)
local summaryBannerGrad = addGradient(summaryHeaderBox, Color3.fromRGB(32, 82, 148), Color3.fromRGB(20, 42, 84), 120)

local summaryWinnerLabel = Instance.new("TextLabel")
summaryWinnerLabel.Size = UDim2.new(1, -20, 0, 34)
summaryWinnerLabel.Position = UDim2.fromOffset(10, 8)
summaryWinnerLabel.BackgroundTransparency = 1
summaryWinnerLabel.Font = Enum.Font.GothamBlack
summaryWinnerLabel.TextSize = 22
summaryWinnerLabel.TextColor3 = Color3.fromRGB(255, 235, 110)
summaryWinnerLabel.Text = "🏆 HIDERS WIN!"
summaryWinnerLabel.ZIndex = 40
summaryWinnerLabel.Parent = summaryHeaderBox

local summarySubLabel = Instance.new("TextLabel")
summarySubLabel.Size = UDim2.new(1, -20, 0, 22)
summarySubLabel.Position = UDim2.fromOffset(10, 42)
summarySubLabel.BackgroundTransparency = 1
summarySubLabel.Font = Enum.Font.GothamBold
summarySubLabel.TextSize = 13
summarySubLabel.TextColor3 = Color3.fromRGB(165, 255, 190)
summarySubLabel.Text = "✨ ทีมที่ชนะได้รับรางวัล +50 Coins & +1 Win!"
summarySubLabel.ZIndex = 40
summarySubLabel.Parent = summaryHeaderBox

local mvpHiderLabel = Instance.new("TextLabel")
mvpHiderLabel.Size = UDim2.new(1, -32, 0, 52)
mvpHiderLabel.Position = UDim2.fromOffset(16, 98)
mvpHiderLabel.BackgroundColor3 = Color3.fromRGB(24, 32, 48)
mvpHiderLabel.Font = Enum.Font.GothamBold
mvpHiderLabel.TextSize = 14
mvpHiderLabel.TextColor3 = Color3.fromRGB(110, 210, 255)
mvpHiderLabel.Text = "🥇 ซ่อนรอดนานสุด: -"
mvpHiderLabel.ZIndex = 39
mvpHiderLabel.Parent = summaryCard
addCorner(mvpHiderLabel, 12)
addBorderStroke(mvpHiderLabel, Color3.fromRGB(75, 185, 255), 1.2, 0.45)

local mvpSeekerLabel = Instance.new("TextLabel")
mvpSeekerLabel.Size = UDim2.new(1, -32, 0, 52)
mvpSeekerLabel.Position = UDim2.fromOffset(16, 160)
mvpSeekerLabel.BackgroundColor3 = Color3.fromRGB(24, 32, 48)
mvpSeekerLabel.Font = Enum.Font.GothamBold
mvpSeekerLabel.TextSize = 14
mvpSeekerLabel.TextColor3 = Color3.fromRGB(255, 120, 125)
mvpSeekerLabel.Text = "⚔️ มือปราบ Seeker: -"
mvpSeekerLabel.ZIndex = 39
mvpSeekerLabel.Parent = summaryCard
addCorner(mvpSeekerLabel, 12)
addBorderStroke(mvpSeekerLabel, Color3.fromRGB(255, 95, 105), 1.2, 0.45)

local dismissSummaryBtn = Instance.new("TextButton")
dismissSummaryBtn.Size = UDim2.new(1, -32, 0, 36)
dismissSummaryBtn.Position = UDim2.fromOffset(16, 224)
dismissSummaryBtn.BackgroundColor3 = Color3.fromRGB(36, 122, 192)
dismissSummaryBtn.AutoButtonColor = false
dismissSummaryBtn.Font = Enum.Font.GothamBlack
dismissSummaryBtn.TextSize = 13
dismissSummaryBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
dismissSummaryBtn.Text = "👁️ ปิดหน้าต่างเพื่อเดินดูจุดซ่อนผู้รอดชีวิต!"
dismissSummaryBtn.ZIndex = 40
dismissSummaryBtn.Parent = summaryCard
addCorner(dismissSummaryBtn, 10)
addBorderStroke(dismissSummaryBtn, Color3.fromRGB(130, 215, 255), 1.4, 0.2)

dismissSummaryBtn.Activated:Connect(function()
	summaryCard.Visible = false
end)

roundEventNotice.OnClientEvent:Connect(function(eventType: string, payload: { [string]: any }?)
	if eventType == "RoundSummary" and typeof(payload) == "table" then
		local winningSide = tostring(payload.WinningSide or "Hiders")
		local bestHider = tostring(payload.BestHiderName or "-")
		local bestTime = tonumber(payload.BestHiderSurvival) or 0
		local bestSeeker = tostring(payload.BestSeekerName or "-")
		local bestKills = tonumber(payload.BestSeekerKills) or 0
		local survCount = tonumber(payload.SurvivorCount) or 0
		local survNames = tostring(payload.SurvivorNames or "")

		if winningSide == "Seekers" then
			summaryWinnerLabel.Text = "🏆 SEEKERS WIN! (ฝ่ายหาชนะ)"
			summaryBannerGrad.Color = ColorSequence.new(Color3.fromRGB(152, 34, 48), Color3.fromRGB(78, 20, 32))
			summaryStroke.Color = Color3.fromRGB(255, 95, 105)
			summarySubLabel.Text = "✨ ฝ่ายหาจับผู้ซ่อนครบทุกคน! (+50 Coins & +1 Win)"
		else
			summaryWinnerLabel.Text = "🏆 HIDERS WIN! (ฝ่ายซ่อนชนะ)"
			summaryBannerGrad.Color = ColorSequence.new(Color3.fromRGB(28, 95, 168), Color3.fromRGB(18, 46, 92))
			summaryStroke.Color = Color3.fromRGB(85, 205, 255)
			summarySubLabel.Text = if survCount > 0 and survNames ~= ""
				then string.format("🎉 ผู้รอดชีวิต (%d): %s", survCount, survNames)
				else "✨ ทีมที่ชนะได้รับรางวัล +50 Coins & +1 Win!"
		end

		dismissSummaryBtn.Text = if survCount > 0
			then "👁️ ปิดหน้าต่างเพื่อเดินดูตัวกระพริบผู้รอดชีวิต (15 วิ)"
			else "✓ ปิดหน้าต่างสรุปผล"

		mvpHiderLabel.Text = string.format("🥇 ซ่อนรอดนานสุด: %s (%d วินาที)", bestHider, bestTime)
		mvpSeekerLabel.Text = string.format("⚔️ มือปราบ Seeker: %s (%d Kills)", bestSeeker, bestKills)
		summaryCard.Visible = true

		local winSound = Instance.new("Sound")
		winSound.SoundId = "rbxassetid://9114074147"
		winSound.Volume = 0.85
		winSound.PlaybackSpeed = 1.1
		winSound.Parent = screenGui
		winSound:Play()
		Debris:AddItem(winSound, 3)

		task.delay(4.5, function()
			summaryCard.Visible = false
		end)
	end
end)

--------------------------------------------------------------------------------
-- 6. AMBIENT TENSION AUDIO & REAL-TIME UPDATES
--------------------------------------------------------------------------------
local bgmSound = Instance.new("Sound")
bgmSound.Name = "PhaseAmbientSound"
bgmSound.SoundId = "rbxassetid://9114074403"
bgmSound.Looped = false
bgmSound.Volume = 0.2
bgmSound.Parent = screenGui

local function formatTimeMMSS(totalSeconds: number): string
	local clamped = math.max(0, math.floor(totalSeconds))
	local minutes = math.floor(clamped / 60)
	local seconds = clamped % 60
	return string.format("%02d:%02d", minutes, seconds)
end

local function syncHudVisibilityWithLobbyMenu()
	local lobbyOpen = localPlayer:GetAttribute("LobbyMenuOpen") == true
	local isLobbyTeam = not localPlayer.Team or localPlayer.Team.Name == "Lobby"
	local shouldHideForModal = lobbyOpen and isLobbyTeam
	topBarFrame.Visible = not shouldHideForModal
	roleHealthFrame.Visible = not shouldHideForModal
end

local lastShownIntroRoundKey = ""

local function playMapIntroBanner(theme: MapHudTheme)
	introStroke.Color = theme.Accent
	introGrad.Color = ColorSequence.new(theme.GradA, theme.GradB)
	introTitleLbl.Text = theme.Title
	introTitleLbl.TextColor3 = theme.Accent
	introSubLbl.Text = theme.Sub

	mapIntroCard.Position = UDim2.new(0.5, 0, 0, 96)
	mapIntroCard.Visible = true
	TweenService:Create(mapIntroCard, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0, 108),
		BackgroundTransparency = 0.08,
	}):Play()
	TweenService:Create(introStroke, TweenInfo.new(0.35), { Transparency = 0.15 }):Play()
	TweenService:Create(introTagLbl, TweenInfo.new(0.35), { TextTransparency = 0 }):Play()
	TweenService:Create(introTitleLbl, TweenInfo.new(0.35), { TextTransparency = 0 }):Play()
	TweenService:Create(introSubLbl, TweenInfo.new(0.35), { TextTransparency = 0 }):Play()

	task.delay(3.6, function()
		TweenService:Create(mapIntroCard, TweenInfo.new(0.45), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(introStroke, TweenInfo.new(0.45), { Transparency = 1 }):Play()
		TweenService:Create(introTagLbl, TweenInfo.new(0.45), { TextTransparency = 1 }):Play()
		TweenService:Create(introTitleLbl, TweenInfo.new(0.45), { TextTransparency = 1 }):Play()
		TweenService:Create(introSubLbl, TweenInfo.new(0.45), { TextTransparency = 1 }):Play()
		task.wait(0.48)
		if introTitleLbl.TextTransparency >= 0.95 then
			mapIntroCard.Visible = false
		end
	end)
end

local function updateMapHudTheme()
	local mapId = tostring(workspace:GetAttribute("ActiveMapId") or "GrandPlaza")
	local theme = MAP_HUD_THEMES[mapId] or MAP_HUD_THEMES.GrandPlaza
	mapLocationLabel.Text = theme.Badge
	mapLocationLabel.TextColor3 = theme.Accent
end

local function updateTopStatusBar()
	local rawState = workspace:GetAttribute("RoundState")
	local rawTimer = workspace:GetAttribute("RoundTimer")
	local rawStatus = workspace:GetAttribute("RoundStatus")
	local mapId = tostring(workspace:GetAttribute("ActiveMapId") or "GrandPlaza")
	local theme = MAP_HUD_THEMES[mapId] or MAP_HUD_THEMES.GrandPlaza

	updateMapHudTheme()

	if rawState == "HidingPhase" then
		local introKey = mapId .. "_Hiding"
		if lastShownIntroRoundKey ~= introKey then
			lastShownIntroRoundKey = introKey
			playMapIntroBanner(theme)
		end
	elseif rawState ~= "HuntingPhase" then
		lastShownIntroRoundKey = ""
	end

	local timerNum = if typeof(rawTimer) == "number" then rawTimer else 0
	timerLabel.Text = formatTimeMMSS(timerNum)

	if rawState == "HuntingPhase" and timerNum > 0 and timerNum <= 15 then
		timerLabel.TextColor3 = Color3.fromRGB(255, 85, 85)
		bgmSound.SoundId = "rbxassetid://12222124"
		bgmSound.PlaybackSpeed = 1.9
		bgmSound.Volume = 0.25
		bgmSound:Play()
	else
		timerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	end

	if rawState == "Intermission" then
		stateLabel.Text = "🟠 กำลังนับถอยหลังเลือกแมพ"
		stateLabel.TextColor3 = Color3.fromRGB(255, 210, 85)
		topBarStroke.Color = Color3.fromRGB(255, 195, 70)
	elseif rawState == "HidingPhase" then
		stateLabel.Text = "🟦 ช่วงเวลาซ่อนตัว (HIDING PHASE)"
		stateLabel.TextColor3 = Color3.fromRGB(85, 205, 255)
		topBarStroke.Color = Color3.fromRGB(75, 195, 255)
	elseif rawState == "HuntingPhase" then
		stateLabel.Text = "🟥 ช่วงเวลาออกล่า (HUNTING PHASE)"
		stateLabel.TextColor3 = Color3.fromRGB(255, 105, 110)
		topBarStroke.Color = Color3.fromRGB(255, 90, 98)
	elseif rawState == "RoundOver" then
		stateLabel.Text = if typeof(rawStatus) == "string" then "🏆 " .. rawStatus else "🏆 จบรอบการแข่งขัน"
		stateLabel.TextColor3 = Color3.fromRGB(255, 220, 80)
		topBarStroke.Color = Color3.fromRGB(255, 215, 75)
	else
		stateLabel.Text = "🟢 ล็อบบี้เตรียมพร้อมก่อนเริ่มเกม"
		stateLabel.TextColor3 = Color3.fromRGB(185, 205, 235)
		topBarStroke.Color = PANEL_STROKE_COLOR
	end

	if rawState ~= "HuntingPhase" then
		seekerHintCard.Visible = false
		clearSeekerHintVisuals()
	end

	syncHudVisibilityWithLobbyMenu()
end

local function updateRoleAndControls()
	local teamName = if localPlayer.Team then localPlayer.Team.Name else "Lobby"
	local character = localPlayer.Character
	local isLocked = character and character:GetAttribute("IsPropLocked") == true
	local sizeClass = character and character:GetAttribute("PropSizeClass")

	if teamName == "Hiders" then
		local sizeSuffix = if typeof(sizeClass) == "string" then string.format(" • %s", sizeClass) else ""
		roleLabel.Text = if isLocked then "🟦 HIDER [ล็อกตัว]" .. sizeSuffix else "🟦 HIDER" .. sizeSuffix
		roleLabel.TextColor3 = ROLE_COLORS.Hiders
		roleCardStroke.Color = ROLE_COLORS.Hiders
		hiderControlsFrame.Visible = true
		seekerControlsFrame.Visible = false

		lockHintDesc.Text = if isLocked
			then "ปลดล็อก [F] • ส่องดูเพื่อน [V]"
			else "ล็อกตัวนิ่ง • หมุน 45°"
		lockHintDesc.TextColor3 = if isLocked
			then Color3.fromRGB(95, 255, 150)
			else Color3.fromRGB(225, 234, 250)
	elseif teamName == "Seekers" then
		roleLabel.Text = "🟥 SEEKER (ฝ่ายล่า)"
		roleLabel.TextColor3 = ROLE_COLORS.Seekers
		roleCardStroke.Color = ROLE_COLORS.Seekers
		hiderControlsFrame.Visible = false
		seekerControlsFrame.Visible = true
	else
		roleLabel.Text = "🏠 LOBBY"
		roleLabel.TextColor3 = ROLE_COLORS.Lobby
		roleCardStroke.Color = PANEL_STROKE_COLOR
		hiderControlsFrame.Visible = false
		seekerControlsFrame.Visible = false
	end

	if teamName ~= "Seekers" then
		seekerHintCard.Visible = false
		clearSeekerHintVisuals()
	end

	syncHudVisibilityWithLobbyMenu()
end

local function updateHealthBar(health: number, maxHealth: number)
	local safeMax = if maxHealth > 0 then maxHealth else 100
	local ratio = math.clamp(health / safeMax, 0, 1)

	healthValueLabel.Text = string.format("❤️ %d / %d HP", math.ceil(math.max(0, health)), math.ceil(safeMax))

	if ratio > 0.5 then
		hpGrad.Color = ColorSequence.new(Color3.fromRGB(95, 245, 140), Color3.fromRGB(36, 175, 86))
	elseif ratio > 0.25 then
		hpGrad.Color = ColorSequence.new(Color3.fromRGB(255, 210, 75), Color3.fromRGB(215, 138, 28))
	else
		hpGrad.Color = ColorSequence.new(Color3.fromRGB(255, 95, 95), Color3.fromRGB(195, 36, 48))
	end

	TweenService:Create(healthBarFill, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromScale(ratio, 1),
	}):Play()
end

local function bindHudCoins()
	local function attach(ls: Instance)
		local c = ls:WaitForChild("Coins", 5) :: IntValue?
		if c then
			hudCoinsBadge.Text = string.format("💰 %d C", c.Value)
			c.Changed:Connect(function()
				hudCoinsBadge.Text = string.format("💰 %d C", c.Value)
			end)
		end
	end
	local existing = localPlayer:FindFirstChild("leaderstats")
	if existing then
		task.spawn(attach, existing)
	end
	localPlayer.ChildAdded:Connect(function(ch)
		if ch.Name == "leaderstats" then
			task.spawn(attach, ch)
		end
	end)
end
bindHudCoins()

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

workspace:GetAttributeChangedSignal("RoundState"):Connect(updateTopStatusBar)
workspace:GetAttributeChangedSignal("RoundTimer"):Connect(updateTopStatusBar)
workspace:GetAttributeChangedSignal("RoundStatus"):Connect(updateTopStatusBar)
workspace:GetAttributeChangedSignal("ActiveMapId"):Connect(updateMapHudTheme)
localPlayer:GetAttributeChangedSignal("LobbyMenuOpen"):Connect(syncHudVisibilityWithLobbyMenu)
localPlayer:GetPropertyChangedSignal("Team"):Connect(updateRoleAndControls)

if localPlayer.Character then
	task.spawn(bindCharacter, localPlayer.Character)
end
localPlayer.CharacterAdded:Connect(bindCharacter)

updateTopStatusBar()
updateRoleAndControls()
