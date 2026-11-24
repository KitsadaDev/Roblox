--!strict
-- StarterPlayerScripts/Client/LobbyUi.client.luau
-- Modern Glassmorphic Lobby Waiting Dashboard, Visual Map Voting Showcase, Boutique Shop, Quests & Leaderboard!

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")

--------------------------------------------------------------------------------
-- ENERGETIC INSTRUMENTAL LOBBY BGM PLAYLIST (100% ดนตรีมันส์ๆ ไม่มีเสียงร้อง!)
--------------------------------------------------------------------------------
local LOBBY_BGM_TRACKS: { { Name: string, Id: string } } = {
	{ Name = "🎸 Rock Groove", Id = "rbxassetid://9046858098" }, -- Stomping Guitar Riff & Drums (Instrumental)
	{ Name = "🎺 Funk Break", Id = "rbxassetid://9041954284" }, -- Energetic Breakbeat & Brass (Instrumental)
	{ Name = "⚡ Heavy Riff", Id = "rbxassetid://9038319810" }, -- High-Energy Rock Lead Guitar (Instrumental)
	{ Name = "🎹 Thai Synth", Id = "rbxassetid://85080568671547" }, -- Thailand Electronic Synthwave (Instrumental)
}
local LOBBY_BGM_VOLUME = 0.42

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui

local PropRemotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PropRemotes"))
local MobileActionBus = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MobileActionBus"))
local abilityRequestEvent = PropRemotes.AbilityRequest
local voteMapEvent = PropRemotes.VoteMapRequest
local startGameEvent = PropRemotes.StartGameRequest

--------------------------------------------------------------------------------
-- THEME & CONFIGURATION
--------------------------------------------------------------------------------
type MapOption = {
	Id: string,
	Tag: string,
	Icon: string,
	Title: string,
	Sub: string,
	Color: Color3,
	GradStart: Color3,
	GradEnd: Color3,
}

local MAP_OPTIONS: { MapOption } = {
	{
		Id = "GrandPlaza",
		Tag = "MAP 01",
		Icon = "🏢",
		Title = "ออฟฟิศ & อาร์เคด",
		Sub = "สำนักงาน ห้องสมุด โกดัง & โซนตู้เกม",
		Color = Color3.fromRGB(75, 190, 255),
		GradStart = Color3.fromRGB(28, 82, 148),
		GradEnd = Color3.fromRGB(18, 42, 82),
	},
	{
		Id = "CyberpunkMall",
		Tag = "MAP 02",
		Icon = "🌆",
		Title = "ห้างไซเบอร์พังก์",
		Sub = "เมืองนีออนอนาคต & ห้องเซิร์ฟเวอร์",
		Color = Color3.fromRGB(235, 80, 225),
		GradStart = Color3.fromRGB(115, 28, 138),
		GradEnd = Color3.fromRGB(32, 24, 86),
	},
	{
		Id = "SchoolCampus",
		Tag = "MAP 03",
		Icon = "🏫",
		Title = "โรงเรียนมัธยม",
		Sub = "ห้องเรียน โรงอาหาร & สนามบาสโรงยิม",
		Color = Color3.fromRGB(255, 185, 65),
		GradStart = Color3.fromRGB(142, 84, 24),
		GradEnd = Color3.fromRGB(68, 42, 22),
	},
	{
		Id = "CampingPark",
		Tag = "MAP 04",
		Icon = "🏕️",
		Title = "แคมป์ปิ้งพาร์ค",
		Sub = "เต็นท์แคมป์ กองไฟ ลำธาร & ป่าสนยามเย็น",
		Color = Color3.fromRGB(85, 225, 125),
		GradStart = Color3.fromRGB(26, 108, 62),
		GradEnd = Color3.fromRGB(18, 54, 42),
	},
	{
		Id = "JapaneseVillage",
		Tag = "MAP 05",
		Icon = "⛩️",
		Title = "หมู่บ้านซากุระ",
		Sub = "เสาโทริอิ สระปลาคราฟ ร้านราเมง & สวนซากุระ",
		Color = Color3.fromRGB(255, 130, 185),
		GradStart = Color3.fromRGB(138, 42, 86),
		GradEnd = Color3.fromRGB(58, 24, 52),
	},
	{
		Id = "MedievalCastle",
		Tag = "MAP 06",
		Icon = "🏰",
		Title = "ปราสาทยุคกลาง",
		Sub = "โถงราชา หอเวทมนตร์ ตลาด & โรงตีเหล็ก",
		Color = Color3.fromRGB(255, 105, 95),
		GradStart = Color3.fromRGB(132, 34, 42),
		GradEnd = Color3.fromRGB(56, 24, 34),
	},
	{
		Id = "Random",
		Tag = "RANDOM",
		Icon = "🎲",
		Title = "สุ่มแมพปริศนา",
		Sub = "สุ่มจากทั้ง 6 แมพใหญ่แบบตื่นเต้น!",
		Color = Color3.fromRGB(255, 215, 75),
		GradStart = Color3.fromRGB(135, 98, 22),
		GradEnd = Color3.fromRGB(58, 44, 20),
	},
}

local MAP_NAMES_BY_ID: { [string]: string } = {
	GrandPlaza = "1. ออฟฟิศ & อาร์เคดพลาซ่า",
	CyberpunkMall = "2. ห้างไซเบอร์พังก์นีออน",
	SchoolCampus = "3. โรงเรียนมัธยม",
	CampingPark = "4. แคมป์ปิ้งพาร์คยามเย็น",
	JapaneseVillage = "5. หมู่บ้านซากุระญี่ปุ่น",
	MedievalCastle = "6. ปราสาทยุคกลาง",
	Random = "สุ่มแมพ (Random)",
}

type SkinOption = {
	Id: string,
	Name: string,
	Rarity: string,
	Desc: string,
	Cost: number,
	Color: Color3,
	Secondary: Color3,
}

local SKIN_OPTIONS: { SkinOption } = {
	{
		Id = "Default",
		Name = "สกินปกติ",
		Rarity = "STANDARD",
		Desc = "รูปลักษณ์เนียนกลมกลืนไปกับฉากจริง",
		Cost = 0,
		Color = Color3.fromRGB(185, 198, 220),
		Secondary = Color3.fromRGB(95, 108, 135),
	},
	{
		Id = "GoldProp",
		Name = "ทองคำแท้ ✨",
		Rarity = "RARE",
		Desc = "เคลือบทองคำเงางามพร้อมประกายระยิบ",
		Cost = 100,
		Color = Color3.fromRGB(255, 210, 60),
		Secondary = Color3.fromRGB(180, 115, 18),
	},
	{
		Id = "NeonCyan",
		Name = "นีออนไซเบอร์ ⚡",
		Rarity = "EPIC",
		Desc = "เรืองแสงสีฟ้าไซเบอร์สุดล้ำสะดุดตา",
		Cost = 150,
		Color = Color3.fromRGB(0, 235, 255),
		Secondary = Color3.fromRGB(20, 95, 195),
	},
	{
		Id = "RubySparkle",
		Name = "ทับทิมส่องแสง 💎",
		Rarity = "MYTHIC",
		Desc = "อัญมณีสีแดงเข้มเปล่งประกายหรูหรา",
		Cost = 200,
		Color = Color3.fromRGB(255, 75, 115),
		Secondary = Color3.fromRGB(135, 18, 55),
	},
	{
		Id = "GhostForceField",
		Name = "วิญญาณลี้ลับ 👻",
		Rarity = "LEGENDARY",
		Desc = "ออร่าโปร่งแสงพลังงานสนามแม่เหล็ก",
		Cost = 250,
		Color = Color3.fromRGB(165, 215, 255),
		Secondary = Color3.fromRGB(85, 95, 215),
	},
}

--------------------------------------------------------------------------------
-- UI HELPER UTILITIES (Always ApplyStrokeMode.Border!)
--------------------------------------------------------------------------------
local function addCorner(parent: Instance, radius: number): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
	return c
end

local function addBorderStroke(parent: Instance, color: Color3, thickness: number, transparency: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Color = color
	s.Thickness = thickness
	s.Transparency = transparency or 0.25
	s.Parent = parent
	return s
end

local function addGradient(parent: Instance, c0: Color3, c1: Color3, rotation: number?): UIGradient
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(c0, c1)
	g.Rotation = rotation or 90
	g.Parent = parent
	return g
end

local function bindHoverGlow(btn: GuiButton, stroke: UIStroke?, baseBg: Color3, hoverBg: Color3, baseTrans: number?)
	local restTrans = baseTrans or 0.35
	btn.MouseEnter:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundColor3 = hoverBg,
		}):Play()
		if stroke then
			TweenService:Create(stroke, TweenInfo.new(0.16), {
				Transparency = 0,
			}):Play()
		end
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundColor3 = baseBg,
		}):Play()
		if stroke then
			TweenService:Create(stroke, TweenInfo.new(0.18), {
				Transparency = restTrans,
			}):Play()
		end
	end)
end

--------------------------------------------------------------------------------
-- CREATE LOBBY SCREENGUI & BACKDROP BLUR
--------------------------------------------------------------------------------
local existing = playerGui:FindFirstChild("PropHuntLobbyGui")
if existing then
	existing:Destroy()
end

local lobbyBlur = Lighting:FindFirstChild("LobbyMenuBlur") :: BlurEffect?
if not lobbyBlur then
	lobbyBlur = Instance.new("BlurEffect")
	lobbyBlur.Name = "LobbyMenuBlur"
	lobbyBlur.Size = 0
	lobbyBlur.Enabled = true
	lobbyBlur.Parent = Lighting
end

local lobbyGui = Instance.new("ScreenGui")
lobbyGui.Name = "PropHuntLobbyGui"
lobbyGui.ResetOnSpawn = false
lobbyGui.IgnoreGuiInset = true
lobbyGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
lobbyGui.Parent = playerGui

-- Subtle translucent backdrop when Dashboard is open (click outside or button to walk around)
local backdropDim = Instance.new("Frame")
backdropDim.Name = "BackdropDim"
backdropDim.Size = UDim2.fromScale(1, 1)
backdropDim.BackgroundColor3 = Color3.fromRGB(6, 9, 16)
backdropDim.BackgroundTransparency = 0.45
backdropDim.BorderSizePixel = 0
backdropDim.ZIndex = 24
backdropDim.Parent = lobbyGui

-- Floating Top-Left Button to Toggle the Lobby Dashboard anytime while in Lobby
local openLobbyBtn = Instance.new("TextButton")
openLobbyBtn.Name = "ToggleLobbyMenuBtn"
openLobbyBtn.Size = UDim2.new(0, 212, 0, 42)
openLobbyBtn.Position = UDim2.new(0, 20, 0, 68)
openLobbyBtn.BackgroundColor3 = Color3.fromRGB(22, 28, 44)
openLobbyBtn.AutoButtonColor = false
openLobbyBtn.Font = Enum.Font.GothamBlack
openLobbyBtn.TextSize = 13
openLobbyBtn.TextColor3 = Color3.fromRGB(255, 222, 85)
openLobbyBtn.Text = "🏠 เปิดเมนูล็อบบี้ / โหวตแมพ"
openLobbyBtn.ZIndex = 45
openLobbyBtn.Parent = lobbyGui
addCorner(openLobbyBtn, 12)
local openBtnStroke = addBorderStroke(openLobbyBtn, Color3.fromRGB(255, 205, 70), 1.8, 0.15)
bindHoverGlow(openLobbyBtn, openBtnStroke, Color3.fromRGB(22, 28, 44), Color3.fromRGB(34, 44, 68), 0.15)

local openBtnScale = Instance.new("UIScale")
openBtnScale.Parent = openLobbyBtn

--------------------------------------------------------------------------------
-- MAIN GLASSMORPHIC DASHBOARD SHELL (840 x 540 + Responsive UIScale)
--------------------------------------------------------------------------------
local DASHBOARD_W = 840
local DASHBOARD_H = 540

local mainCard = Instance.new("Frame")
mainCard.Name = "LobbyDashboard"
mainCard.Size = UDim2.fromOffset(DASHBOARD_W, DASHBOARD_H)
mainCard.Position = UDim2.fromScale(0.5, 0.5)
mainCard.AnchorPoint = Vector2.new(0.5, 0.5)
mainCard.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
mainCard.BackgroundTransparency = 0.04
mainCard.BorderSizePixel = 0
mainCard.ZIndex = 30
mainCard.Parent = lobbyGui
addCorner(mainCard, 20)
addBorderStroke(mainCard, Color3.fromRGB(95, 175, 255), 2, 0.25)
addGradient(mainCard, Color3.fromRGB(24, 31, 50), Color3.fromRGB(13, 17, 28), 115)

local uiScale = Instance.new("UIScale")
uiScale.Parent = mainCard

local function updateDashboardScale()
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local vp = cam.ViewportSize
	local isPhone = MobileActionBus.IsCompactPhone()

	-- Keep ToggleLobbyMenuBtn clear of left iPhone notch/Dynamic Island (52px) + Roblox TopBar Unibar (58px) + TopStatusBar
	openBtnScale.Scale = if isPhone then 0.76 else 1.0
	openLobbyBtn.Position = if isPhone then UDim2.fromOffset(52, 58) else UDim2.new(0, 20, 0, 68)

	if vp.X > 0 and vp.Y > 0 then
		local padX = if isPhone then 96 else 36
		local padY = if isPhone then 24 else 36
		local minScale = if isPhone then 0.45 else 0.58
		local sx = (vp.X - padX) / DASHBOARD_W
		local sy = (vp.Y - padY) / DASHBOARD_H
		uiScale.Scale = math.clamp(math.min(sx, sy), minScale, 1.06)
	end
end
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateDashboardScale)
	updateDashboardScale()
end

--------------------------------------------------------------------------------
-- 1. TOP HEADER BAR (Brand Title, Status Pill, Live Coins/Wins & Walk Around)
--------------------------------------------------------------------------------
local headerFrame = Instance.new("Frame")
headerFrame.Name = "Header"
headerFrame.Size = UDim2.new(1, -32, 0, 68)
headerFrame.Position = UDim2.new(0, 16, 0, 14)
headerFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
headerFrame.BackgroundTransparency = 0.08
headerFrame.BorderSizePixel = 0
headerFrame.ZIndex = 31
headerFrame.Parent = mainCard
addCorner(headerFrame, 14)
addBorderStroke(headerFrame, Color3.fromRGB(75, 115, 175), 1.2, 0.4)
addGradient(headerFrame, Color3.fromRGB(30, 39, 62), Color3.fromRGB(18, 24, 40), 0)

-- Emblem Icon Box
local emblemBox = Instance.new("Frame")
emblemBox.Size = UDim2.fromOffset(44, 44)
emblemBox.Position = UDim2.new(0, 12, 0.5, 0)
emblemBox.AnchorPoint = Vector2.new(0, 0.5)
emblemBox.BackgroundColor3 = Color3.fromRGB(255, 195, 55)
emblemBox.BorderSizePixel = 0
emblemBox.ZIndex = 32
emblemBox.Parent = headerFrame
addCorner(emblemBox, 12)
addGradient(emblemBox, Color3.fromRGB(255, 225, 95), Color3.fromRGB(235, 135, 35), 135)

local emblemIcon = Instance.new("TextLabel")
emblemIcon.Size = UDim2.fromScale(1, 1)
emblemIcon.BackgroundTransparency = 1
emblemIcon.Font = Enum.Font.GothamBlack
emblemIcon.TextSize = 24
emblemIcon.Text = "🎭"
emblemIcon.ZIndex = 33
emblemIcon.Parent = emblemBox

local gameTitle = Instance.new("TextLabel")
gameTitle.Size = UDim2.new(0, 280, 0, 26)
gameTitle.Position = UDim2.new(0, 66, 0, 10)
gameTitle.BackgroundTransparency = 1
gameTitle.Font = Enum.Font.GothamBlack
gameTitle.TextSize = 21
gameTitle.TextXAlignment = Enum.TextXAlignment.Left
gameTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
gameTitle.Text = "PROP HUNT PLAZA"
gameTitle.ZIndex = 32
gameTitle.Parent = headerFrame
addGradient(gameTitle, Color3.fromRGB(255, 235, 120), Color3.fromRGB(255, 180, 65), 0)

local subStatusLabel = Instance.new("TextLabel")
subStatusLabel.Size = UDim2.new(0, 286, 0, 20)
subStatusLabel.Position = UDim2.new(0, 66, 0, 37)
subStatusLabel.BackgroundTransparency = 1
subStatusLabel.Font = Enum.Font.GothamMedium
subStatusLabel.TextSize = 12
subStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
subStatusLabel.TextTruncate = Enum.TextTruncate.AtEnd
subStatusLabel.TextColor3 = Color3.fromRGB(170, 198, 235)
subStatusLabel.Text = "🟢 พร้อมเริ่มเกม • โหวตแมพที่ชอบแล้วกดเริ่มเกมได้เลย!"
subStatusLabel.ZIndex = 32
subStatusLabel.Parent = headerFrame

-- Live Coins Balance Pill
local coinsPill = Instance.new("Frame")
coinsPill.Size = UDim2.fromOffset(94, 36)
coinsPill.Position = UDim2.new(1, -362, 0.5, 0)
coinsPill.AnchorPoint = Vector2.new(1, 0.5)
coinsPill.BackgroundColor3 = Color3.fromRGB(36, 32, 22)
coinsPill.BorderSizePixel = 0
coinsPill.ZIndex = 32
coinsPill.Parent = headerFrame
addCorner(coinsPill, 10)
addBorderStroke(coinsPill, Color3.fromRGB(255, 205, 65), 1.4, 0.25)

local coinsTextLabel = Instance.new("TextLabel")
coinsTextLabel.Size = UDim2.new(1, -12, 1, 0)
coinsTextLabel.Position = UDim2.fromOffset(6, 0)
coinsTextLabel.BackgroundTransparency = 1
coinsTextLabel.Font = Enum.Font.GothamBlack
coinsTextLabel.TextSize = 13
coinsTextLabel.TextColor3 = Color3.fromRGB(255, 220, 75)
coinsTextLabel.Text = "💰 0 C"
coinsTextLabel.ZIndex = 33
coinsTextLabel.Parent = coinsPill

-- Lobby Music Track Switcher / Mute Button
local bgmToggleBtn = Instance.new("TextButton")
bgmToggleBtn.Name = "LobbyBgmToggleBtn"
bgmToggleBtn.Size = UDim2.fromOffset(92, 36)
bgmToggleBtn.Position = UDim2.new(1, -262, 0.5, 0)
bgmToggleBtn.AnchorPoint = Vector2.new(1, 0.5)
bgmToggleBtn.BackgroundColor3 = Color3.fromRGB(32, 42, 64)
bgmToggleBtn.AutoButtonColor = false
bgmToggleBtn.Font = Enum.Font.GothamBold
bgmToggleBtn.TextSize = 11
bgmToggleBtn.TextColor3 = Color3.fromRGB(145, 235, 185)
bgmToggleBtn.Text = "🎸 ดนตรี 1"
bgmToggleBtn.ZIndex = 32
bgmToggleBtn.Parent = headerFrame
addCorner(bgmToggleBtn, 10)
local bgmStroke = addBorderStroke(bgmToggleBtn, Color3.fromRGB(95, 215, 150), 1.3, 0.35)

-- AFK Toggle Button
local afkToggleBtn = Instance.new("TextButton")
afkToggleBtn.Name = "AfkToggleButton"
afkToggleBtn.Size = UDim2.fromOffset(104, 36)
afkToggleBtn.Position = UDim2.new(1, -154, 0.5, 0)
afkToggleBtn.AnchorPoint = Vector2.new(1, 0.5)
afkToggleBtn.BackgroundColor3 = Color3.fromRGB(36, 44, 64)
afkToggleBtn.AutoButtonColor = false
afkToggleBtn.Font = Enum.Font.GothamBold
afkToggleBtn.TextSize = 12
afkToggleBtn.TextColor3 = Color3.fromRGB(205, 220, 245)
afkToggleBtn.Text = "💤 พัก (AFK)"
afkToggleBtn.ZIndex = 32
afkToggleBtn.Parent = headerFrame
addCorner(afkToggleBtn, 10)
local afkStroke = addBorderStroke(afkToggleBtn, Color3.fromRGB(95, 120, 168), 1.3, 0.35)

afkToggleBtn.Activated:Connect(function()
	abilityRequestEvent:FireServer("ToggleAFK")
end)

-- Walk Around Lobby (Minimize) Button
local minimizeBtn = Instance.new("TextButton")
minimizeBtn.Name = "WalkAroundButton"
minimizeBtn.Size = UDim2.fromOffset(132, 36)
minimizeBtn.Position = UDim2.new(1, -14, 0.5, 0)
minimizeBtn.AnchorPoint = Vector2.new(1, 0.5)
minimizeBtn.BackgroundColor3 = Color3.fromRGB(36, 128, 195)
minimizeBtn.AutoButtonColor = false
minimizeBtn.Font = Enum.Font.GothamBlack
minimizeBtn.TextSize = 12
minimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
minimizeBtn.Text = "👁️ เดินชมล็อบบี้"
minimizeBtn.ZIndex = 32
minimizeBtn.Parent = headerFrame
addCorner(minimizeBtn, 10)
local minStroke = addBorderStroke(minimizeBtn, Color3.fromRGB(130, 215, 255), 1.4, 0.2)
addGradient(minimizeBtn, Color3.fromRGB(52, 158, 235), Color3.fromRGB(28, 102, 175), 90)
bindHoverGlow(minimizeBtn, minStroke, Color3.fromRGB(36, 128, 195), Color3.fromRGB(52, 148, 220), 0.2)

--------------------------------------------------------------------------------
-- 2. NAVIGATION TAB BAR + PERSISTENT "START GAME" CTA BUTTON
--------------------------------------------------------------------------------
local navBar = Instance.new("Frame")
navBar.Name = "NavigationBar"
navBar.Size = UDim2.new(1, -32, 0, 44)
navBar.Position = UDim2.new(0, 16, 0, 92)
navBar.BackgroundTransparency = 1
navBar.ZIndex = 31
navBar.Parent = mainCard

local tabTrack = Instance.new("Frame")
tabTrack.Size = UDim2.new(1, -242, 1, 0)
tabTrack.BackgroundColor3 = Color3.fromRGB(18, 23, 36)
tabTrack.BorderSizePixel = 0
tabTrack.ZIndex = 31
tabTrack.Parent = navBar
addCorner(tabTrack, 12)
addBorderStroke(tabTrack, Color3.fromRGB(58, 74, 110), 1.2, 0.45)

local tabListLayout = Instance.new("UIListLayout")
tabListLayout.FillDirection = Enum.FillDirection.Horizontal
tabListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
tabListLayout.VerticalAlignment = Enum.VerticalAlignment.Center
tabListLayout.Padding = UDim.new(0, 5)
tabListLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabListLayout.Parent = tabTrack

local tabPadding = Instance.new("UIPadding")
tabPadding.PaddingLeft = UDim.new(0, 5)
tabPadding.PaddingRight = UDim.new(0, 5)
tabPadding.Parent = tabTrack

type TabId = "Maps" | "Shop" | "Quests" | "Leaderboard"
local activeTab: TabId = "Maps"
local tabButtons: { [TabId]: TextButton } = {}
local tabPages: { [TabId]: Frame } = {}

local TAB_DEFS: { { Id: TabId, Label: string, Width: number } } = {
	{ Id = "Maps", Label = "🗺️ โหวตแมพ (6 แมพ)", Width = 144 },
	{ Id = "Shop", Label = "🛒 ร้านค้า & สกิน", Width = 130 },
	{ Id = "Quests", Label = "📋 ภารกิจ & วิธีเล่น", Width = 136 },
	{ Id = "Leaderboard", Label = "🏆 อันดับผู้เล่น", Width = 126 },
}

for idx, def in TAB_DEFS do
	local tBtn = Instance.new("TextButton")
	tBtn.Name = "Tab_" .. def.Id
	tBtn.Size = UDim2.fromOffset(def.Width, 34)
	tBtn.LayoutOrder = idx
	tBtn.AutoButtonColor = false
	tBtn.BackgroundColor3 = Color3.fromRGB(36, 88, 168)
	tBtn.Font = Enum.Font.GothamBold
	tBtn.TextSize = 12
	tBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	tBtn.Text = def.Label
	tBtn.ZIndex = 32
	tBtn.Parent = tabTrack
	addCorner(tBtn, 9)
	tabButtons[def.Id] = tBtn
end

-- Primary Start Game CTA Button (Always accessible on the right of NavBar!)
local startGameBtn = Instance.new("TextButton")
startGameBtn.Name = "StartGameButton"
startGameBtn.Size = UDim2.fromOffset(230, 44)
startGameBtn.Position = UDim2.new(1, 0, 0.5, 0)
startGameBtn.AnchorPoint = Vector2.new(1, 0.5)
startGameBtn.BackgroundColor3 = Color3.fromRGB(36, 195, 92)
startGameBtn.AutoButtonColor = false
startGameBtn.Font = Enum.Font.GothamBlack
startGameBtn.TextSize = 14
startGameBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
startGameBtn.Text = "▶ เริ่มเกม (โหวต 30 วิ)"
startGameBtn.ZIndex = 33
startGameBtn.Parent = navBar
addCorner(startGameBtn, 12)
local startBtnStroke = addBorderStroke(startGameBtn, Color3.fromRGB(150, 255, 185), 1.8, 0.1)
local startBtnGrad = addGradient(startGameBtn, Color3.fromRGB(58, 222, 112), Color3.fromRGB(24, 152, 72), 90)

startGameBtn.Activated:Connect(function()
	startGameEvent:FireServer()
end)

--------------------------------------------------------------------------------
-- CONTENT CONTAINER FOR PAGES
--------------------------------------------------------------------------------
local pagesContainer = Instance.new("Frame")
pagesContainer.Name = "PagesContainer"
pagesContainer.Size = UDim2.new(1, -32, 1, -162)
pagesContainer.Position = UDim2.new(0, 16, 0, 146)
pagesContainer.BackgroundTransparency = 1
pagesContainer.ZIndex = 31
pagesContainer.Parent = mainCard

local function createPageFrame(id: TabId): Frame
	local page = Instance.new("Frame")
	page.Name = "Page_" .. id
	page.Size = UDim2.fromScale(1, 1)
	page.BackgroundTransparency = 1
	page.Visible = (id == activeTab)
	page.ZIndex = 31
	page.Parent = pagesContainer
	tabPages[id] = page
	return page
end

local function switchTab(target: TabId)
	activeTab = target
	for id, page in tabPages do
		page.Visible = (id == target)
	end
	for id, btn in tabButtons do
		local isSel = (id == target)
		TweenService:Create(btn, TweenInfo.new(0.16), {
			BackgroundColor3 = if isSel then Color3.fromRGB(48, 118, 220) else Color3.fromRGB(24, 30, 46),
			BackgroundTransparency = if isSel then 0 else 0.35,
			TextColor3 = if isSel then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(170, 186, 215),
		}):Play()
	end
end

for id, btn in tabButtons do
	btn.Activated:Connect(function()
		switchTab(id)
	end)
end

--------------------------------------------------------------------------------
-- PAGE 1: MAP VOTING SHOWCASE ("Maps")
--------------------------------------------------------------------------------
local mapsPage = createPageFrame("Maps")

-- Leading Vote & Live Glass Preview Info Bar
local mapStatusStrip = Instance.new("Frame")
mapStatusStrip.Size = UDim2.new(1, 0, 0, 32)
mapStatusStrip.BackgroundColor3 = Color3.fromRGB(22, 28, 44)
mapStatusStrip.BorderSizePixel = 0
mapStatusStrip.ZIndex = 32
mapStatusStrip.Parent = mapsPage
addCorner(mapStatusStrip, 10)
addBorderStroke(mapStatusStrip, Color3.fromRGB(68, 95, 145), 1, 0.45)

local leadingVoteLabel = Instance.new("TextLabel")
leadingVoteLabel.Size = UDim2.new(0.52, -16, 1, 0)
leadingVoteLabel.Position = UDim2.fromOffset(12, 0)
leadingVoteLabel.BackgroundTransparency = 1
leadingVoteLabel.Font = Enum.Font.GothamBold
leadingVoteLabel.TextSize = 12
leadingVoteLabel.TextXAlignment = Enum.TextXAlignment.Left
leadingVoteLabel.TextColor3 = Color3.fromRGB(255, 218, 80)
leadingVoteLabel.Text = "👑 โหวตนำ: สุ่มแมพ (Random)"
leadingVoteLabel.ZIndex = 33
leadingVoteLabel.Parent = mapStatusStrip

local activePreviewLabel = Instance.new("TextLabel")
activePreviewLabel.Size = UDim2.new(0.48, -16, 1, 0)
activePreviewLabel.Position = UDim2.new(1, -12, 0, 0)
activePreviewLabel.AnchorPoint = Vector2.new(1, 0)
activePreviewLabel.BackgroundTransparency = 1
activePreviewLabel.Font = Enum.Font.GothamMedium
activePreviewLabel.TextSize = 12
activePreviewLabel.TextXAlignment = Enum.TextXAlignment.Right
activePreviewLabel.TextColor3 = Color3.fromRGB(145, 215, 255)
activePreviewLabel.Text = "🔍 แมพใต้พื้นกระจก: 1. ออฟฟิศ & อาร์เคดพลาซ่า"
activePreviewLabel.ZIndex = 33
activePreviewLabel.Parent = mapStatusStrip

-- 7 Visual Map Cards Grid with Live 3D ViewportFrame Architectural Dioramas!
local mapButtonsById: { [string]: TextButton } = {}
local viewportOrbitEntries: { { Cam: Camera, Focus: Vector3, Radius: number, Height: number, Phase: number } } = {}

local function vPart(
	parent: Instance,
	size: Vector3,
	cf: CFrame,
	col: Color3,
	mat: Enum.Material?,
	shape: Enum.PartType?,
	trans: number?
): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = mat or Enum.Material.SmoothPlastic
	p.Color = col
	if shape then
		p.Shape = shape
	end
	if trans then
		p.Transparency = trans
	end
	p.Size = size
	p.CFrame = cf
	p.Parent = parent
	return p
end

local function populateMapViewportDiorama(vp: ViewportFrame, mapId: string)
	local wm = Instance.new("WorldModel")
	wm.Parent = vp

	local cam = Instance.new("Camera")
	cam.FieldOfView = 38
	cam.Parent = vp
	vp.CurrentCamera = cam

	local focus = Vector3.new(0, 2.2, 0)
	local radius = 14.5
	local camHeight = 6.2

	if mapId == "GrandPlaza" then
		vp.Ambient = Color3.fromRGB(145, 155, 175)
		vp.LightColor = Color3.fromRGB(255, 248, 232)
		vp.LightDirection = Vector3.new(-0.6, -1, -0.5)
		vPart(wm, Vector3.new(26, 0.5, 26), CFrame.new(0, -0.25, 0), Color3.fromRGB(208, 202, 192), Enum.Material.Marble)
		vPart(wm, Vector3.new(12, 0.55, 10), CFrame.new(5, -0.22, -3), Color3.fromRGB(152, 106, 68), Enum.Material.WoodPlanks)
		vPart(wm, Vector3.new(26, 9, 0.6), CFrame.new(0, 4.5, -9.5), Color3.fromRGB(224, 218, 206), Enum.Material.Concrete)
		vPart(wm, Vector3.new(26, 2.2, 0.75), CFrame.new(0, 1.1, -9.4), Color3.fromRGB(118, 82, 52), Enum.Material.Wood)
		-- Marble Fountain
		vPart(wm, Vector3.new(0.9, 6.2, 6.2), CFrame.new(-1.5, 0.45, 0.5) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(232, 228, 220), Enum.Material.Marble, Enum.PartType.Cylinder)
		vPart(wm, Vector3.new(0.75, 5.2, 5.2), CFrame.new(-1.5, 0.6, 0.5) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(72, 195, 255), Enum.Material.Glass, Enum.PartType.Cylinder, 0.2)
		vPart(wm, Vector3.new(2.8, 1.2, 1.2), CFrame.new(-1.5, 1.8, 0.5) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(225, 220, 212), Enum.Material.Marble, Enum.PartType.Cylinder)
		vPart(wm, Vector3.new(1.2, 1.2, 1.2), CFrame.new(-1.5, 3.5, 0.5), Color3.fromRGB(120, 225, 255), Enum.Material.Neon, Enum.PartType.Ball)
		-- Executive Desk & Arcade
		vPart(wm, Vector3.new(4.0, 1.8, 2.0), CFrame.new(4.2, 0.9, -1.2) * CFrame.Angles(0, math.rad(-20), 0), Color3.fromRGB(145, 98, 62), Enum.Material.Wood)
		vPart(wm, Vector3.new(1.8, 1.2, 0.2), CFrame.new(4.2, 2.4, -1.4) * CFrame.Angles(0, math.rad(-20), 0), Color3.fromRGB(75, 195, 255), Enum.Material.Neon)
		vPart(wm, Vector3.new(2.0, 4.4, 1.8), CFrame.new(-5.2, 2.2, -2.5) * CFrame.Angles(0, math.rad(25), 0), Color3.fromRGB(32, 36, 48), Enum.Material.Metal)
		vPart(wm, Vector3.new(1.5, 1.3, 0.2), CFrame.new(-4.8, 2.8, -1.7) * CFrame.Angles(0, math.rad(25), 0), Color3.fromRGB(195, 75, 255), Enum.Material.Neon)
	elseif mapId == "CyberpunkMall" then
		vp.Ambient = Color3.fromRGB(78, 58, 128)
		vp.LightColor = Color3.fromRGB(165, 225, 255)
		vp.LightDirection = Vector3.new(-0.4, -1, -0.6)
		vPart(wm, Vector3.new(26, 0.5, 26), CFrame.new(0, -0.25, 0), Color3.fromRGB(18, 22, 34), Enum.Material.Metal)
		for g = -2, 2 do
			vPart(wm, Vector3.new(24, 0.08, 0.22), CFrame.new(0, 0.04, g * 3.2), Color3.fromRGB(0, 225, 255), Enum.Material.Neon)
			vPart(wm, Vector3.new(0.22, 0.08, 24), CFrame.new(g * 3.2, 0.04, 0), Color3.fromRGB(235, 55, 195), Enum.Material.Neon)
		end
		-- Holo Crystal & Orbit Rings
		vPart(wm, Vector3.new(0.5, 5.5, 5.5), CFrame.new(0, 0.25, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(0, 230, 255), Enum.Material.Neon, Enum.PartType.Cylinder)
		vPart(wm, Vector3.new(2.0, 4.2, 2.0), CFrame.new(0, 2.9, 0) * CFrame.Angles(math.rad(18), math.rad(45), math.rad(18)), Color3.fromRGB(0, 235, 255), Enum.Material.Neon, nil, 0.15)
		vPart(wm, Vector3.new(4.8, 0.22, 4.8), CFrame.new(0, 2.9, 0) * CFrame.Angles(math.rad(28), 0, math.rad(22)), Color3.fromRGB(255, 65, 210), Enum.Material.Neon)
		-- Server Racks
		for _, sx in { -4.8, 4.8 } do
			vPart(wm, Vector3.new(2.0, 5.2, 2.0), CFrame.new(sx, 2.6, -2.5), Color3.fromRGB(26, 30, 44), Enum.Material.Metal)
			vPart(wm, Vector3.new(1.5, 3.8, 0.15), CFrame.new(sx, 2.6, -1.45), if sx < 0 then Color3.fromRGB(245, 65, 205) else Color3.fromRGB(0, 230, 255), Enum.Material.Neon)
		end
	elseif mapId == "SchoolCampus" then
		vp.Ambient = Color3.fromRGB(155, 148, 138)
		vp.LightColor = Color3.fromRGB(255, 250, 235)
		vp.LightDirection = Vector3.new(-0.5, -1, -0.5)
		vPart(wm, Vector3.new(26, 0.5, 26), CFrame.new(0, -0.25, 0), Color3.fromRGB(185, 142, 92), Enum.Material.WoodPlanks)
		vPart(wm, Vector3.new(24, 8.5, 0.6), CFrame.new(0, 4.2, -7.2), Color3.fromRGB(236, 230, 215), Enum.Material.Concrete)
		vPart(wm, Vector3.new(9.5, 4.0, 0.25), CFrame.new(0, 4.2, -6.8), Color3.fromRGB(36, 88, 56), Enum.Material.SmoothPlastic)
		-- Lockers & Desks
		for i, lx in { -6.0, -4.3, 4.3, 6.0 } do
			vPart(wm, Vector3.new(1.5, 4.8, 1.5), CFrame.new(lx, 2.4, -5.8), if i <= 2 then Color3.fromRGB(52, 122, 205) else Color3.fromRGB(205, 62, 62), Enum.Material.Metal)
		end
		for _, dx in { -2.4, 2.4 } do
			vPart(wm, Vector3.new(2.2, 1.6, 1.6), CFrame.new(dx, 0.8, 0.8), Color3.fromRGB(165, 118, 72), Enum.Material.Wood)
		end
	elseif mapId == "CampingPark" then
		vp.Ambient = Color3.fromRGB(135, 105, 82)
		vp.LightColor = Color3.fromRGB(255, 198, 128)
		vp.LightDirection = Vector3.new(-0.7, -0.8, -0.4)
		vPart(wm, Vector3.new(26, 0.5, 26), CFrame.new(0, -0.25, 0), Color3.fromRGB(66, 128, 62), Enum.Material.Grass)
		vPart(wm, Vector3.new(0.3, 6.2, 6.2), CFrame.new(0, 0.05, 1.2) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(145, 140, 132), Enum.Material.Cobblestone, Enum.PartType.Cylinder)
		-- Glowing Campfire
		vPart(wm, Vector3.new(1.8, 0.5, 1.8), CFrame.new(0, 0.35, 1.2), Color3.fromRGB(108, 68, 38), Enum.Material.Wood)
		vPart(wm, Vector3.new(1.5, 1.8, 1.5), CFrame.new(0, 1.2, 1.2), Color3.fromRGB(255, 135, 35), Enum.Material.Neon, Enum.PartType.Ball)
		-- Tent & Pine Trees
		vPart(wm, Vector3.new(3.8, 2.8, 4.2), CFrame.new(-3.8, 1.4, -1.8) * CFrame.Angles(0, math.rad(28), math.rad(0)), Color3.fromRGB(235, 128, 42), Enum.Material.Fabric)
		for _, tx in { 4.2, -5.8, 2.2 } do
			local tz = if tx == 2.2 then -4.8 else -2.2
			vPart(wm, Vector3.new(2.2, 0.9, 0.9), CFrame.new(tx, 1.1, tz) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(92, 60, 36), Enum.Material.Wood, Enum.PartType.Cylinder)
			vPart(wm, Vector3.new(3.4, 3.8, 3.4), CFrame.new(tx, 3.4, tz), Color3.fromRGB(46, 112, 58), Enum.Material.Grass, Enum.PartType.Ball)
		end
	elseif mapId == "JapaneseVillage" then
		vp.Ambient = Color3.fromRGB(145, 108, 122)
		vp.LightColor = Color3.fromRGB(255, 215, 225)
		vp.LightDirection = Vector3.new(-0.5, -0.9, -0.5)
		vPart(wm, Vector3.new(26, 0.5, 26), CFrame.new(0, -0.25, 0), Color3.fromRGB(98, 132, 78), Enum.Material.Grass)
		vPart(wm, Vector3.new(0.35, 8.5, 8.5), CFrame.new(0, 0.05, 1.5) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(58, 162, 208), Enum.Material.Glass, Enum.PartType.Cylinder, 0.15)
		-- Vermilion Torii Gate
		for _, px in { -2.4, 2.4 } do
			vPart(wm, Vector3.new(5.2, 0.65, 0.65), CFrame.new(px, 2.6, -1.2) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(215, 44, 42), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		end
		vPart(wm, Vector3.new(6.8, 0.55, 0.7), CFrame.new(0, 4.9, -1.2), Color3.fromRGB(215, 44, 42), Enum.Material.SmoothPlastic)
		vPart(wm, Vector3.new(7.4, 0.35, 0.9), CFrame.new(0, 5.3, -1.2), Color3.fromRGB(36, 38, 46), Enum.Material.Slate)
		-- Blooming Sakura Tree
		vPart(wm, Vector3.new(3.2, 0.8, 0.8), CFrame.new(4.4, 1.6, 0.2) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(92, 62, 46), Enum.Material.Wood, Enum.PartType.Cylinder)
		vPart(wm, Vector3.new(4.2, 3.0, 4.2), CFrame.new(4.4, 3.8, 0.2), Color3.fromRGB(255, 138, 185), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	elseif mapId == "MedievalCastle" then
		vp.Ambient = Color3.fromRGB(110, 104, 122)
		vp.LightColor = Color3.fromRGB(255, 212, 155)
		vp.LightDirection = Vector3.new(-0.5, -0.9, -0.5)
		vPart(wm, Vector3.new(26, 0.5, 26), CFrame.new(0, -0.25, 0), Color3.fromRGB(118, 114, 108), Enum.Material.Cobblestone)
		vPart(wm, Vector3.new(4.2, 0.12, 18), CFrame.new(0, 0.06, 0), Color3.fromRGB(162, 32, 44), Enum.Material.Fabric)
		-- Castle Wall + Merlons
		vPart(wm, Vector3.new(18, 5.2, 1.4), CFrame.new(0, 2.6, -5.8), Color3.fromRGB(108, 104, 98), Enum.Material.Cobblestone)
		for m = -6, 6, 3 do
			vPart(wm, Vector3.new(1.6, 1.2, 1.6), CFrame.new(m, 5.8, -5.8), Color3.fromRGB(122, 118, 112), Enum.Material.Cobblestone)
		end
		-- Excalibur Sword-in-the-Stone & Fire Brazier
		vPart(wm, Vector3.new(2.8, 2.0, 2.8), CFrame.new(0, 1.0, 0.4), Color3.fromRGB(92, 90, 88), Enum.Material.Rock, Enum.PartType.Ball)
		vPart(wm, Vector3.new(0.32, 3.6, 0.14), CFrame.new(0, 3.2, 0.4), Color3.fromRGB(210, 235, 255), Enum.Material.Neon)
		vPart(wm, Vector3.new(1.5, 0.28, 0.35), CFrame.new(0, 4.4, 0.4), Color3.fromRGB(240, 195, 65), Enum.Material.Metal)
		vPart(wm, Vector3.new(1.4, 1.4, 1.4), CFrame.new(-3.8, 1.4, 0.8), Color3.fromRGB(255, 125, 35), Enum.Material.Neon, Enum.PartType.Ball)
	else
		vp.Ambient = Color3.fromRGB(135, 118, 85)
		vp.LightColor = Color3.fromRGB(255, 235, 165)
		vp.LightDirection = Vector3.new(-0.5, -1, -0.5)
		vPart(wm, Vector3.new(26, 0.5, 26), CFrame.new(0, -0.25, 0), Color3.fromRGB(34, 30, 24), Enum.Material.Marble)
		vPart(wm, Vector3.new(0.6, 6.2, 6.2), CFrame.new(0, 0.3, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(235, 188, 55), Enum.Material.Metal, Enum.PartType.Cylinder)
		vPart(wm, Vector3.new(2.8, 2.8, 2.8), CFrame.new(0, 2.8, 0) * CFrame.Angles(math.rad(25), math.rad(45), math.rad(20)), Color3.fromRGB(255, 215, 70), Enum.Material.Neon)
		for idxCol, colOrb in {
			Color3.fromRGB(75, 195, 255),
			Color3.fromRGB(235, 80, 225),
			Color3.fromRGB(85, 225, 125),
			Color3.fromRGB(255, 105, 95),
		} do
			local ang = (idxCol - 1) * (math.pi * 0.5)
			vPart(
				wm,
				Vector3.new(1.2, 1.2, 1.2),
				CFrame.new(math.cos(ang) * 4.2, 2.4, math.sin(ang) * 4.2),
				colOrb,
				Enum.Material.Neon,
				Enum.PartType.Ball
			)
		end
	end

	local initAngle = 0.45
	cam.CFrame = CFrame.lookAt(
		focus + Vector3.new(math.sin(initAngle) * radius, camHeight, math.cos(initAngle) * radius),
		focus
	)

	table.insert(viewportOrbitEntries, {
		Cam = cam,
		Focus = focus,
		Radius = radius,
		Height = camHeight,
		Phase = #viewportOrbitEntries * 0.9,
	})
end

for idx, opt in MAP_OPTIONS do
	local isFirstRow = idx <= 4
	local col = if isFirstRow then idx else (idx - 4)
	local cardWidthScale = if isFirstRow then 0.241 else 0.324
	local xPosScale = if isFirstRow
		then ((col - 1) * 0.253)
		else ((col - 1) * 0.338)
	local yPosOffset = if isFirstRow then 40 else 186
	local cardHeight = if isFirstRow then 138 else 136

	local baseCardColor = Color3.fromRGB(20, 25, 38)
	local hoverCardColor = Color3.fromRGB(28, 35, 54)

	local mBtn = Instance.new("TextButton")
	mBtn.Name = "MapBtn_" .. opt.Id
	mBtn.Size = UDim2.new(cardWidthScale, 0, 0, cardHeight)
	mBtn.Position = UDim2.new(xPosScale, 0, 0, yPosOffset)
	mBtn.BackgroundColor3 = baseCardColor
	mBtn.AutoButtonColor = false
	mBtn.Text = ""
	mBtn.ClipsDescendants = true
	mBtn.ZIndex = 32
	mBtn.Parent = mapsPage
	addCorner(mBtn, 14)

	local cardStroke = addBorderStroke(mBtn, opt.Color, 1.6, 0.42)
	cardStroke.Name = "CardStroke"

	-- Realistic 3D ViewportFrame Thumbnail Banner
	local banner = Instance.new("Frame")
	banner.Name = "Banner"
	banner.Size = UDim2.new(1, -10, 0, 68)
	banner.Position = UDim2.fromOffset(5, 5)
	banner.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	banner.BorderSizePixel = 0
	banner.ClipsDescendants = true
	banner.ZIndex = 33
	banner.Parent = mBtn
	addCorner(banner, 10)
	addGradient(banner, opt.GradStart, opt.GradEnd, 135)

	local vpFrame = Instance.new("ViewportFrame")
	vpFrame.Name = "Preview3D"
	vpFrame.Size = UDim2.fromScale(1, 1)
	vpFrame.BackgroundTransparency = 0.22
	vpFrame.BackgroundColor3 = opt.GradEnd
	vpFrame.BorderSizePixel = 0
	vpFrame.ZIndex = 33
	vpFrame.Parent = banner
	addCorner(vpFrame, 10)
	populateMapViewportDiorama(vpFrame, opt.Id)

	-- Subtle bottom cinematic vignette inside banner for crisp badge contrast
	local vignette = Instance.new("Frame")
	vignette.Size = UDim2.new(1, 0, 0.45, 0)
	vignette.Position = UDim2.fromScale(0, 0.55)
	vignette.BackgroundColor3 = Color3.fromRGB(10, 14, 24)
	vignette.BorderSizePixel = 0
	vignette.ZIndex = 34
	vignette.Parent = banner
	local vigGrad = Instance.new("UIGradient")
	vigGrad.Rotation = 90
	vigGrad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0.25),
	})
	vigGrad.Parent = vignette

	-- Map Number Tag Pill (Top-Left of Banner)
	local mapTagPill = Instance.new("TextLabel")
	mapTagPill.Size = UDim2.fromOffset(58, 18)
	mapTagPill.Position = UDim2.fromOffset(6, 6)
	mapTagPill.BackgroundColor3 = Color3.fromRGB(10, 14, 22)
	mapTagPill.BackgroundTransparency = 0.18
	mapTagPill.Font = Enum.Font.GothamBlack
	mapTagPill.TextSize = 10
	mapTagPill.TextColor3 = opt.Color
	mapTagPill.Text = opt.Tag
	mapTagPill.ZIndex = 35
	mapTagPill.Parent = banner
	addCorner(mapTagPill, 6)
	addBorderStroke(mapTagPill, opt.Color, 1, 0.5)

	-- Leading Crown Pill (Top-Right of Banner, shown when leading!)
	local leadBadge = Instance.new("TextLabel")
	leadBadge.Name = "LeadBadge"
	leadBadge.Size = UDim2.fromOffset(58, 18)
	leadBadge.Position = UDim2.new(1, -6, 0, 6)
	leadBadge.AnchorPoint = Vector2.new(1, 0)
	leadBadge.BackgroundColor3 = Color3.fromRGB(245, 185, 38)
	leadBadge.Font = Enum.Font.GothamBlack
	leadBadge.TextSize = 10
	leadBadge.TextColor3 = Color3.fromRGB(25, 20, 10)
	leadBadge.Text = "👑 นำอยู่"
	leadBadge.Visible = false
	leadBadge.ZIndex = 35
	leadBadge.Parent = banner
	addCorner(leadBadge, 6)

	-- Map Title & Subtitle
	local titleLbl = Instance.new("TextLabel")
	titleLbl.Name = "Title"
	titleLbl.Size = UDim2.new(1, -18, 0, 18)
	titleLbl.Position = UDim2.fromOffset(9, 75)
	titleLbl.BackgroundTransparency = 1
	titleLbl.Font = Enum.Font.GothamBlack
	titleLbl.TextSize = 13
	titleLbl.TextXAlignment = Enum.TextXAlignment.Left
	titleLbl.TextTruncate = Enum.TextTruncate.AtEnd
	titleLbl.TextColor3 = Color3.fromRGB(248, 250, 255)
	titleLbl.Text = opt.Icon .. " " .. opt.Title
	titleLbl.ZIndex = 33
	titleLbl.Parent = mBtn

	local subLbl = Instance.new("TextLabel")
	subLbl.Name = "Sub"
	subLbl.Size = UDim2.new(1, -18, 0, 15)
	subLbl.Position = UDim2.fromOffset(9, 93)
	subLbl.BackgroundTransparency = 1
	subLbl.Font = Enum.Font.GothamMedium
	subLbl.TextSize = 10
	subLbl.TextXAlignment = Enum.TextXAlignment.Left
	subLbl.TextTruncate = Enum.TextTruncate.AtEnd
	subLbl.TextColor3 = Color3.fromRGB(168, 184, 212)
	subLbl.Text = opt.Sub
	subLbl.ZIndex = 33
	subLbl.Parent = mBtn

	-- Bottom Vote Pill
	local voteBadge = Instance.new("TextLabel")
	voteBadge.Name = "VoteBadge"
	voteBadge.Size = UDim2.new(1, -16, 0, 22)
	voteBadge.Position = UDim2.new(0, 8, 1, -27)
	voteBadge.BackgroundColor3 = Color3.fromRGB(14, 18, 28)
	voteBadge.Font = Enum.Font.GothamBold
	voteBadge.TextSize = 11
	voteBadge.TextColor3 = Color3.fromRGB(215, 225, 245)
	voteBadge.Text = "คลิกโหวต • 0 โหวต"
	voteBadge.ZIndex = 33
	voteBadge.Parent = mBtn
	addCorner(voteBadge, 7)

	mBtn.MouseEnter:Connect(function()
		TweenService:Create(mBtn, TweenInfo.new(0.15), { BackgroundColor3 = hoverCardColor }):Play()
	end)
	mBtn.MouseLeave:Connect(function()
		TweenService:Create(mBtn, TweenInfo.new(0.18), { BackgroundColor3 = baseCardColor }):Play()
	end)

	mBtn.Activated:Connect(function()
		voteMapEvent:FireServer(opt.Id)
	end)

	mapButtonsById[opt.Id] = mBtn
end

-- Smoothly pan the 3D ViewportFrame diorama cameras ONLY while the Maps tab is visible!
RunService.RenderStepped:Connect(function()
	if not mainCard.Visible or activeTab ~= "Maps" then
		return
	end
	local t = os.clock()
	for _, item in viewportOrbitEntries do
		local ang = 0.42 + math.sin(t * 0.45 + item.Phase) * 0.48
		item.Cam.CFrame = CFrame.lookAt(
			item.Focus + Vector3.new(math.sin(ang) * item.Radius, item.Height, math.cos(ang) * item.Radius),
			item.Focus
		)
	end
end)

-- Bottom Quick Loadout & Shortcut Footer on Maps Page
local quickFooter = Instance.new("Frame")
quickFooter.Size = UDim2.new(1, 0, 0, 42)
quickFooter.Position = UDim2.new(0, 0, 1, 0)
quickFooter.AnchorPoint = Vector2.new(0, 1)
quickFooter.BackgroundColor3 = Color3.fromRGB(20, 26, 40)
quickFooter.BorderSizePixel = 0
quickFooter.ZIndex = 32
quickFooter.Parent = mapsPage
addCorner(quickFooter, 12)
addBorderStroke(quickFooter, Color3.fromRGB(62, 82, 122), 1, 0.45)

local quickLoadoutLabel = Instance.new("TextLabel")
quickLoadoutLabel.Size = UDim2.new(1, -185, 1, 0)
quickLoadoutLabel.Position = UDim2.fromOffset(14, 0)
quickLoadoutLabel.BackgroundTransparency = 1
quickLoadoutLabel.Font = Enum.Font.GothamMedium
quickLoadoutLabel.TextSize = 12
quickLoadoutLabel.TextXAlignment = Enum.TextXAlignment.Left
quickLoadoutLabel.TextTruncate = Enum.TextTruncate.AtEnd
quickLoadoutLabel.TextColor3 = Color3.fromRGB(205, 220, 245)
quickLoadoutLabel.Text = "✨ สกิน: ปกติ  |  🔊 เสียงผิวปาก: Classic  |  📋 ภารกิจสำเร็จ: 0/3"
quickLoadoutLabel.ZIndex = 33
quickLoadoutLabel.Parent = quickFooter

local quickShopJumpBtn = Instance.new("TextButton")
quickShopJumpBtn.Size = UDim2.fromOffset(158, 30)
quickShopJumpBtn.Position = UDim2.new(1, -8, 0.5, 0)
quickShopJumpBtn.AnchorPoint = Vector2.new(1, 0.5)
quickShopJumpBtn.BackgroundColor3 = Color3.fromRGB(48, 62, 96)
quickShopJumpBtn.AutoButtonColor = false
quickShopJumpBtn.Font = Enum.Font.GothamBold
quickShopJumpBtn.TextSize = 11
quickShopJumpBtn.TextColor3 = Color3.fromRGB(255, 220, 85)
quickShopJumpBtn.Text = "🛒 แต่งสกิน & ซื้อ Perk →"
quickShopJumpBtn.ZIndex = 33
quickShopJumpBtn.Parent = quickFooter
addCorner(quickShopJumpBtn, 8)
local qShopStroke = addBorderStroke(quickShopJumpBtn, Color3.fromRGB(255, 205, 70), 1.2, 0.35)
bindHoverGlow(quickShopJumpBtn, qShopStroke, Color3.fromRGB(48, 62, 96), Color3.fromRGB(62, 78, 118), 0.35)
quickShopJumpBtn.Activated:Connect(function()
	switchTab("Shop")
end)

--------------------------------------------------------------------------------
-- PAGE 2: BOUTIQUE PERK & SKIN SHOP ("Shop")
--------------------------------------------------------------------------------
local shopPage = createPageFrame("Shop")

local perksSectionLabel = Instance.new("TextLabel")
perksSectionLabel.Size = UDim2.new(1, 0, 0, 22)
perksSectionLabel.BackgroundTransparency = 1
perksSectionLabel.Font = Enum.Font.GothamBlack
perksSectionLabel.TextSize = 14
perksSectionLabel.TextXAlignment = Enum.TextXAlignment.Left
perksSectionLabel.TextColor3 = Color3.fromRGB(125, 210, 255)
perksSectionLabel.Text = "⚡ อุปกรณ์เสริมพลัง & เสียงผิวปาก (Perks & Taunt Pack)"
perksSectionLabel.ZIndex = 32
perksSectionLabel.Parent = shopPage

local function createPerkCard(
	icon: string,
	title: string,
	desc: string,
	xScale: number,
	widthScale: number,
	accentCol: Color3,
	onClick: () -> ()
): (TextButton, TextLabel)
	local baseCol = Color3.fromRGB(23, 29, 45)
	local hoverCol = Color3.fromRGB(30, 38, 58)

	local card = Instance.new("TextButton")
	card.Size = UDim2.new(widthScale, 0, 0, 108)
	card.Position = UDim2.new(xScale, 0, 0, 26)
	card.BackgroundColor3 = baseCol
	card.AutoButtonColor = false
	card.Text = ""
	card.ZIndex = 32
	card.Parent = shopPage
	addCorner(card, 14)
	local st = addBorderStroke(card, accentCol, 1.6, 0.32)
	bindHoverGlow(card, st, baseCol, hoverCol, 0.32)

	local iconBox = Instance.new("Frame")
	iconBox.Size = UDim2.fromOffset(48, 48)
	iconBox.Position = UDim2.fromOffset(12, 12)
	iconBox.BackgroundColor3 = accentCol
	iconBox.BackgroundTransparency = 0.82
	iconBox.BorderSizePixel = 0
	iconBox.ZIndex = 33
	iconBox.Parent = card
	addCorner(iconBox, 12)
	addBorderStroke(iconBox, accentCol, 1.2, 0.4)

	local iconTxt = Instance.new("TextLabel")
	iconTxt.Size = UDim2.fromScale(1, 1)
	iconTxt.BackgroundTransparency = 1
	iconTxt.Font = Enum.Font.GothamBlack
	iconTxt.TextSize = 24
	iconTxt.Text = icon
	iconTxt.ZIndex = 34
	iconTxt.Parent = iconBox

	local tLbl = Instance.new("TextLabel")
	tLbl.Size = UDim2.new(1, -76, 0, 20)
	tLbl.Position = UDim2.fromOffset(68, 12)
	tLbl.BackgroundTransparency = 1
	tLbl.Font = Enum.Font.GothamBlack
	tLbl.TextSize = 13
	tLbl.TextXAlignment = Enum.TextXAlignment.Left
	tLbl.TextColor3 = accentCol
	tLbl.Text = title
	tLbl.ZIndex = 33
	tLbl.Parent = card

	local dLbl = Instance.new("TextLabel")
	dLbl.Size = UDim2.new(1, -76, 0, 32)
	dLbl.Position = UDim2.fromOffset(68, 32)
	dLbl.BackgroundTransparency = 1
	dLbl.Font = Enum.Font.GothamMedium
	dLbl.TextSize = 11
	dLbl.TextWrapped = true
	dLbl.TextXAlignment = Enum.TextXAlignment.Left
	dLbl.TextYAlignment = Enum.TextYAlignment.Top
	dLbl.TextColor3 = Color3.fromRGB(185, 198, 222)
	dLbl.Text = desc
	dLbl.ZIndex = 33
	dLbl.Parent = card

	local actionPill = Instance.new("TextLabel")
	actionPill.Name = "ActionPill"
	actionPill.Size = UDim2.new(1, -24, 0, 26)
	actionPill.Position = UDim2.new(0, 12, 1, -34)
	actionPill.BackgroundColor3 = Color3.fromRGB(15, 20, 32)
	actionPill.Font = Enum.Font.GothamBold
	actionPill.TextSize = 12
	actionPill.TextColor3 = Color3.fromRGB(255, 220, 80)
	actionPill.Text = "ซื้อใช้งาน"
	actionPill.ZIndex = 33
	actionPill.Parent = card
	addCorner(actionPill, 8)

	card.Activated:Connect(onClick)
	return card, actionPill
end

local _speedCard, speedActionPill = createPerkCard(
	"👟",
	"รองเท้าวิ่งไว (+Speed)",
	"วิ่งไวขึ้นเป็น WalkSpeed 20 สำหรับฝ่ายซ่อน & เดินล็อบบี้",
	0,
	0.355,
	Color3.fromRGB(75, 215, 255),
	function()
		abilityRequestEvent:FireServer("BuySpeedPerk")
	end
)

local _healthCard, healthActionPill = createPerkCard(
	"🛡️",
	"เกราะเพิ่มเลือด (+50 HP)",
	"เพิ่มเลือดสูงสุดเป็น 150 HP รับดาเมจได้มากขึ้น",
	0.368,
	0.355,
	Color3.fromRGB(90, 240, 135),
	function()
		abilityRequestEvent:FireServer("BuyHealthPerk")
	end
)

local _soundCard, soundActionPill = createPerkCard(
	"🔊",
	"เสียงผิวปาก (Taunt)",
	"สลับโทนเสียงล่อ Seeker ตอนกดปุ่ม [T] ได้ฟรี!",
	0.736,
	0.264,
	Color3.fromRGB(255, 195, 75),
	function()
		abilityRequestEvent:FireServer("CycleTauntPack")
	end
)

-- Skins Showcase Section
local skinsSectionLabel = Instance.new("TextLabel")
skinsSectionLabel.Size = UDim2.new(1, 0, 0, 22)
skinsSectionLabel.Position = UDim2.fromOffset(0, 146)
skinsSectionLabel.BackgroundTransparency = 1
skinsSectionLabel.Font = Enum.Font.GothamBlack
skinsSectionLabel.TextSize = 14
skinsSectionLabel.TextXAlignment = Enum.TextXAlignment.Left
skinsSectionLabel.TextColor3 = Color3.fromRGB(255, 215, 80)
skinsSectionLabel.Text = "✨ สกินแปลงร่างสุดพิเศษ (Cosmetic Prop Skins — ซื้อครั้งเดียวใช้ได้ตลอด!)"
skinsSectionLabel.ZIndex = 32
skinsSectionLabel.Parent = shopPage

local skinButtonsById: { [string]: TextButton } = {}

for idx, skin in SKIN_OPTIONS do
	local widthScale = 0.188
	local xScale = (idx - 1) * 0.203
	local baseBg = Color3.fromRGB(22, 27, 42)
	local hoverBg = Color3.fromRGB(30, 37, 56)

	local sBtn = Instance.new("TextButton")
	sBtn.Name = "Skin_" .. skin.Id
	sBtn.Size = UDim2.new(widthScale, 0, 0, 206)
	sBtn.Position = UDim2.new(xScale, 0, 0, 172)
	sBtn.BackgroundColor3 = baseBg
	sBtn.AutoButtonColor = false
	sBtn.Text = ""
	sBtn.ZIndex = 32
	sBtn.Parent = shopPage
	addCorner(sBtn, 14)

	local ss = addBorderStroke(sBtn, skin.Color, 1.6, 0.38)
	ss.Name = "Stroke"

	-- Rarity Tag
	local rarityLbl = Instance.new("TextLabel")
	rarityLbl.Size = UDim2.new(1, -16, 0, 16)
	rarityLbl.Position = UDim2.fromOffset(8, 8)
	rarityLbl.BackgroundTransparency = 1
	rarityLbl.Font = Enum.Font.GothamBlack
	rarityLbl.TextSize = 10
	rarityLbl.TextColor3 = skin.Color
	rarityLbl.Text = skin.Rarity
	rarityLbl.ZIndex = 33
	rarityLbl.Parent = sBtn

	-- Glowing Preview Orb Swatch
	local orbOuter = Instance.new("Frame")
	orbOuter.Size = UDim2.fromOffset(62, 62)
	orbOuter.Position = UDim2.new(0.5, 0, 0, 30)
	orbOuter.AnchorPoint = Vector2.new(0.5, 0)
	orbOuter.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	orbOuter.BorderSizePixel = 0
	orbOuter.ZIndex = 33
	orbOuter.Parent = sBtn
	addCorner(orbOuter, 99)
	addGradient(orbOuter, skin.Color, skin.Secondary, 135)
	addBorderStroke(orbOuter, Color3.fromRGB(255, 255, 255), 1.5, 0.45)

	local orbShine = Instance.new("Frame")
	orbShine.Size = UDim2.fromOffset(20, 12)
	orbShine.Position = UDim2.fromOffset(14, 10)
	orbShine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	orbShine.BackgroundTransparency = 0.45
	orbShine.BorderSizePixel = 0
	orbShine.ZIndex = 34
	orbShine.Parent = orbOuter
	addCorner(orbShine, 99)

	local sTitle = Instance.new("TextLabel")
	sTitle.Name = "Title"
	sTitle.Size = UDim2.new(1, -14, 0, 20)
	sTitle.Position = UDim2.fromOffset(7, 100)
	sTitle.BackgroundTransparency = 1
	sTitle.Font = Enum.Font.GothamBlack
	sTitle.TextSize = 13
	sTitle.TextColor3 = Color3.fromRGB(248, 250, 255)
	sTitle.Text = skin.Name
	sTitle.ZIndex = 33
	sBtn.MouseEnter:Connect(function()
		TweenService:Create(sBtn, TweenInfo.new(0.15), { BackgroundColor3 = hoverBg }):Play()
	end)
	sBtn.MouseLeave:Connect(function()
		TweenService:Create(sBtn, TweenInfo.new(0.18), { BackgroundColor3 = baseBg }):Play()
	end)
	sTitle.Parent = sBtn

	local sDesc = Instance.new("TextLabel")
	sDesc.Size = UDim2.new(1, -18, 0, 36)
	sDesc.Position = UDim2.fromOffset(9, 122)
	sDesc.BackgroundTransparency = 1
	sDesc.Font = Enum.Font.GothamMedium
	sDesc.TextSize = 10
	sDesc.TextWrapped = true
	sDesc.TextColor3 = Color3.fromRGB(168, 184, 212)
	sDesc.Text = skin.Desc
	sDesc.ZIndex = 33
	sDesc.Parent = sBtn

	local sStatus = Instance.new("TextLabel")
	sStatus.Name = "Status"
	sStatus.Size = UDim2.new(1, -18, 0, 28)
	sStatus.Position = UDim2.new(0, 9, 1, -36)
	sStatus.BackgroundColor3 = Color3.fromRGB(15, 20, 32)
	sStatus.Font = Enum.Font.GothamBlack
	sStatus.TextSize = 11
	sStatus.TextColor3 = Color3.fromRGB(255, 215, 75)
	sStatus.Text = if skin.Cost == 0 then "ฟรี" else string.format("💰 %d C", skin.Cost)
	sStatus.ZIndex = 33
	sStatus.Parent = sBtn
	addCorner(sStatus, 8)

	sBtn.Activated:Connect(function()
		abilityRequestEvent:FireServer("BuyOrEquipSkin", skin.Id)
	end)

	skinButtonsById[skin.Id] = sBtn
end

--------------------------------------------------------------------------------
-- PAGE 3: DAILY QUESTS & HOW TO PLAY GUIDE ("Quests")
--------------------------------------------------------------------------------
local questsPage = createPageFrame("Quests")

-- Left Column: Daily Quests with Animated Progress Bars
local questsCol = Instance.new("Frame")
questsCol.Size = UDim2.new(0.48, -6, 1, 0)
questsCol.BackgroundColor3 = Color3.fromRGB(20, 26, 40)
questsCol.BorderSizePixel = 0
questsCol.ZIndex = 32
questsCol.Parent = questsPage
addCorner(questsCol, 14)
addBorderStroke(questsCol, Color3.fromRGB(75, 165, 245), 1.4, 0.38)

local qHeader = Instance.new("TextLabel")
qHeader.Size = UDim2.new(1, -28, 0, 28)
qHeader.Position = UDim2.fromOffset(14, 12)
qHeader.BackgroundTransparency = 1
qHeader.Font = Enum.Font.GothamBlack
qHeader.TextSize = 15
qHeader.TextXAlignment = Enum.TextXAlignment.Left
qHeader.TextColor3 = Color3.fromRGB(255, 220, 80)
qHeader.Text = "📋 ภารกิจรายวันรับเหรียญฟรี!"
qHeader.ZIndex = 33
qHeader.Parent = questsCol

type QuestUiRefs = {
	CountLabel: TextLabel,
	FillBar: Frame,
	RewardBadge: TextLabel,
}
local questRefs: { [string]: QuestUiRefs } = {}

local QUEST_DEFS = {
	{
		Key = "Morph",
		Icon = "🎭",
		Title = "นักปลอมตัวมืออาชีพ",
		Desc = "แปลงร่างเป็นสิ่งของในแมพครบ 5 ครั้ง",
		Reward = "+25 Coins",
		Color = Color3.fromRGB(75, 195, 255),
	},
	{
		Key = "Taunt",
		Icon = "🎵",
		Title = "จอมปั่นประสาท",
		Desc = "กดปุ่ม [T] ผิวปากล่อ Seeker ครบ 3 ครั้ง",
		Reward = "+30 Coins",
		Color = Color3.fromRGB(255, 195, 70),
	},
	{
		Key = "Catch",
		Icon = "🎯",
		Title = "สายสืบตาเหยี่ยว",
		Desc = "เป็น Seeker ยิงจับผู้ซ่อนสำเร็จ 1 คน",
		Reward = "+35 Coins",
		Color = Color3.fromRGB(255, 105, 115),
	},
}

for idx, q in QUEST_DEFS do
	local qCard = Instance.new("Frame")
	qCard.Size = UDim2.new(1, -28, 0, 98)
	qCard.Position = UDim2.fromOffset(14, 48 + (idx - 1) * 108)
	qCard.BackgroundColor3 = Color3.fromRGB(26, 33, 50)
	qCard.BorderSizePixel = 0
	qCard.ZIndex = 33
	qCard.Parent = questsCol
	addCorner(qCard, 12)
	addBorderStroke(qCard, q.Color, 1.2, 0.5)

	local qTitle = Instance.new("TextLabel")
	qTitle.Size = UDim2.new(1, -110, 0, 20)
	qTitle.Position = UDim2.fromOffset(12, 10)
	qTitle.BackgroundTransparency = 1
	qTitle.Font = Enum.Font.GothamBlack
	qTitle.TextSize = 13
	qTitle.TextXAlignment = Enum.TextXAlignment.Left
	qTitle.TextColor3 = Color3.fromRGB(245, 248, 255)
	qTitle.Text = q.Icon .. " " .. q.Title
	qTitle.ZIndex = 34
	qTitle.Parent = qCard

	local rewardPill = Instance.new("TextLabel")
	rewardPill.Size = UDim2.fromOffset(86, 22)
	rewardPill.Position = UDim2.new(1, -10, 0, 9)
	rewardPill.AnchorPoint = Vector2.new(1, 0)
	rewardPill.BackgroundColor3 = Color3.fromRGB(38, 34, 22)
	rewardPill.Font = Enum.Font.GothamBlack
	rewardPill.TextSize = 11
	rewardPill.TextColor3 = Color3.fromRGB(255, 215, 75)
	rewardPill.Text = q.Reward
	rewardPill.ZIndex = 34
	rewardPill.Parent = qCard
	addCorner(rewardPill, 7)

	local qDesc = Instance.new("TextLabel")
	qDesc.Size = UDim2.new(1, -24, 0, 18)
	qDesc.Position = UDim2.fromOffset(12, 33)
	qDesc.BackgroundTransparency = 1
	qDesc.Font = Enum.Font.GothamMedium
	qDesc.TextSize = 11
	qDesc.TextXAlignment = Enum.TextXAlignment.Left
	qDesc.TextColor3 = Color3.fromRGB(175, 190, 218)
	qDesc.Text = q.Desc
	qDesc.ZIndex = 34
	qDesc.Parent = qCard

	local barBg = Instance.new("Frame")
	barBg.Size = UDim2.new(1, -90, 0, 14)
	barBg.Position = UDim2.fromOffset(12, 66)
	barBg.BackgroundColor3 = Color3.fromRGB(14, 18, 28)
	barBg.BorderSizePixel = 0
	barBg.ZIndex = 34
	barBg.Parent = qCard
	addCorner(barBg, 7)

	local barFill = Instance.new("Frame")
	barFill.Size = UDim2.fromScale(0, 1)
	barFill.BackgroundColor3 = q.Color
	barFill.BorderSizePixel = 0
	barFill.ZIndex = 35
	barFill.Parent = barBg
	addCorner(barFill, 7)

	local countLbl = Instance.new("TextLabel")
	countLbl.Size = UDim2.fromOffset(64, 18)
	countLbl.Position = UDim2.new(1, -12, 0, 64)
	countLbl.AnchorPoint = Vector2.new(1, 0)
	countLbl.BackgroundTransparency = 1
	countLbl.Font = Enum.Font.GothamBlack
	countLbl.TextSize = 12
	countLbl.TextXAlignment = Enum.TextXAlignment.Right
	countLbl.TextColor3 = Color3.fromRGB(235, 242, 255)
	countLbl.Text = "0 / 5"
	countLbl.ZIndex = 34
	countLbl.Parent = qCard

	questRefs[q.Key] = {
		CountLabel = countLbl,
		FillBar = barFill,
		RewardBadge = rewardPill,
	}
end

-- Right Column: Hider & Seeker Visual Role Guide
local guideCol = Instance.new("Frame")
guideCol.Size = UDim2.new(0.52, -6, 1, 0)
guideCol.Position = UDim2.new(0.48, 6, 0, 0)
guideCol.BackgroundTransparency = 1
guideCol.ZIndex = 32
guideCol.Parent = questsPage

local function createRoleGuideCard(
	yOffset: number,
	height: number,
	title: string,
	accentCol: Color3,
	lines: { string }
)
	local box = Instance.new("Frame")
	box.Size = UDim2.new(1, 0, 0, height)
	box.Position = UDim2.fromOffset(0, yOffset)
	box.BackgroundColor3 = Color3.fromRGB(20, 26, 40)
	box.BorderSizePixel = 0
	box.ZIndex = 32
	box.Parent = guideCol
	addCorner(box, 14)
	addBorderStroke(box, accentCol, 1.4, 0.35)

	local h = Instance.new("TextLabel")
	h.Size = UDim2.new(1, -28, 0, 24)
	h.Position = UDim2.fromOffset(14, 10)
	h.BackgroundTransparency = 1
	h.Font = Enum.Font.GothamBlack
	h.TextSize = 14
	h.TextXAlignment = Enum.TextXAlignment.Left
	h.TextColor3 = accentCol
	h.Text = title
	h.ZIndex = 33
	h.Parent = box

	for i, line in lines do
		local row = Instance.new("TextLabel")
		row.Size = UDim2.new(1, -28, 0, 22)
		row.Position = UDim2.fromOffset(14, 38 + (i - 1) * 24)
		row.BackgroundTransparency = 1
		row.Font = Enum.Font.GothamMedium
		row.TextSize = 12
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = Color3.fromRGB(220, 230, 248)
		row.Text = line
		row.ZIndex = 33
		row.Parent = box
	end
end

createRoleGuideCard(0, 192, "🟦 คู่มือฝ่ายซ่อน (HIDER CONTROLS)", Color3.fromRGB(75, 195, 255), {
	"• [คลิกซ้าย / ปุ่ม E] แปลงร่างเป็นสิ่งของชิ้นไหนก็ได้ในแมพ!",
	"• [F] ล็อกตำแหน่งตัวนิ่ง  |  [R] หมุนปรับองศา 45° ให้เนียน",
	"• [V] ส่องดูเพื่อนร่วมทีม (เมื่อล็อกตัวอยู่)",
	"• [T] ผิวปากล่อ Seeker รับเหรียญฟรี +5 ถึง +20 Coins!",
	"• [G] วางร่างปลอมหลอก (20 C)  |  [Shift] ระเบิดควันวิ่งหนี",
	"• เลือดตามขนาด Prop: เล็ก 70 HP • กลาง 100 HP • ใหญ่ 140 HP",
})

createRoleGuideCard(202, 176, "🟥 คู่มือฝ่ายหา (SEEKER CONTROLS)", Color3.fromRGB(255, 95, 105), {
	"• [คลิกซ้าย / แตะจอ] ยิงปืนตรวจจับสิ่งของต้องสงสัย (50 ดาเมจ)",
	"• ⚠️ ระวัง! ถ้ายิงพลาดโดนของตกแต่งจริง เลือดลด -15 HP!",
	"• [Q] Sonar Radar สแกนระยะ  |  [E] Speed Surge เร่งสปีด 4 วิ",
	"• 💡 ช่วง 30 วิสุดท้าย จะได้รับคำใบ้โซนซ่อนตัวคร่าวๆ ของ Hider!",
	"• จัดการผู้ซ่อนได้ +15 Coins/Kill • ชนะรอบรับ +50 Coins!",
})

--------------------------------------------------------------------------------
-- PAGE 4: SERVER LEADERBOARD & LIVE ROSTER ("Leaderboard")
--------------------------------------------------------------------------------
local lbPage = createPageFrame("Leaderboard")

local lbPanel = Instance.new("Frame")
lbPanel.Size = UDim2.fromScale(1, 1)
lbPanel.BackgroundColor3 = Color3.fromRGB(20, 26, 40)
lbPanel.BorderSizePixel = 0
lbPanel.ZIndex = 32
lbPanel.Parent = lbPage
addCorner(lbPanel, 14)
addBorderStroke(lbPanel, Color3.fromRGB(75, 115, 175), 1.4, 0.38)

local rosterTitle = Instance.new("TextLabel")
rosterTitle.Size = UDim2.new(0, 260, 0, 30)
rosterTitle.Position = UDim2.fromOffset(16, 12)
rosterTitle.BackgroundTransparency = 1
rosterTitle.Font = Enum.Font.GothamBlack
rosterTitle.TextSize = 15
rosterTitle.TextXAlignment = Enum.TextXAlignment.Left
rosterTitle.TextColor3 = Color3.fromRGB(255, 220, 80)
rosterTitle.Text = "🏆 อันดับผู้เล่นในเซิร์ฟเวอร์ (1 คน)"
rosterTitle.ZIndex = 33
rosterTitle.Parent = lbPanel

local currentLeaderboardMode: "Wins" | "Survival" | "Coins" = "Wins"
local sortButtons: { [string]: TextButton } = {}

for idx, sDef in {
	{ Key = "Wins", Label = "🏆 ชนะสูงสุด", X = -342 },
	{ Key = "Survival", Label = "⏱️ รอดนานสุด", X = -222 },
	{ Key = "Coins", Label = "💰 เหรียญสูงสุด", X = -102 },
} do
	local sb = Instance.new("TextButton")
	sb.Size = UDim2.fromOffset(112, 28)
	sb.Position = UDim2.new(1, sDef.X + 90, 0, 13)
	sb.AnchorPoint = Vector2.new(1, 0)
	sb.AutoButtonColor = false
	sb.BackgroundColor3 = if idx == 1 then Color3.fromRGB(48, 115, 215) else Color3.fromRGB(30, 38, 56)
	sb.Font = Enum.Font.GothamBold
	sb.TextSize = 11
	sb.TextColor3 = Color3.fromRGB(255, 255, 255)
	sb.Text = sDef.Label
	sb.ZIndex = 33
	sb.Parent = lbPanel
	addCorner(sb, 8)
	sortButtons[sDef.Key] = sb
end

local rosterList = Instance.new("ScrollingFrame")
rosterList.Name = "PlayerList"
rosterList.Size = UDim2.new(1, -32, 1, -62)
rosterList.Position = UDim2.fromOffset(16, 50)
rosterList.BackgroundTransparency = 1
rosterList.BorderSizePixel = 0
rosterList.ScrollBarThickness = 5
rosterList.ScrollBarImageColor3 = Color3.fromRGB(95, 145, 225)
rosterList.CanvasSize = UDim2.new(0, 0, 0, 0)
rosterList.AutomaticCanvasSize = Enum.AutomaticSize.Y
rosterList.ZIndex = 33
rosterList.Parent = lbPanel

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 8)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = rosterList

--------------------------------------------------------------------------------
-- REACTIVE STATE UPDATES
--------------------------------------------------------------------------------
local manuallyMinimized = false

local function getStat(p: Player, statName: string): number
	local ls = p:FindFirstChild("leaderstats")
	local valObj = ls and ls:FindFirstChild(statName) :: IntValue?
	return if valObj then valObj.Value else 0
end

local function updateHeaderCoins()
	local myCoins = getStat(localPlayer, "Coins")
	coinsTextLabel.Text = string.format("💰 %d C", myCoins)
end

local function updateMapVoteUI()
	local myVote = tostring(localPlayer:GetAttribute("VotedMap") or "Random")
	local leadingChoice = tostring(workspace:GetAttribute("SelectedMapChoice") or "Random")
	local activeMapId = tostring(workspace:GetAttribute("ActiveMapId") or "GrandPlaza")

	local leadingName = MAP_NAMES_BY_ID[leadingChoice] or "สุ่มแมพ (Random)"
	local activeName = MAP_NAMES_BY_ID[activeMapId] or activeMapId

	leadingVoteLabel.Text = "👑 โหวตนำ: " .. leadingName
	activePreviewLabel.Text = "🔍 แมพใต้พื้นกระจก: " .. activeName

	for _, opt in MAP_OPTIONS do
		local btn = mapButtonsById[opt.Id]
		if not btn then
			continue
		end

		local countAttr = workspace:GetAttribute("Votes_" .. opt.Id)
		local votes = if typeof(countAttr) == "number" then countAttr else 0
		local isSelectedByMe = (myVote == opt.Id)
		local isLeading = (leadingChoice == opt.Id and votes > 0)

		local banner = btn:FindFirstChild("Banner")
		local leadBadge = banner and banner:FindFirstChild("LeadBadge") :: TextLabel?
		if leadBadge then
			leadBadge.Visible = isLeading
		end

		local badge = btn:FindFirstChild("VoteBadge") :: TextLabel?
		if badge then
			badge.Text = if isSelectedByMe
				then string.format("✓ เลือกแล้ว • %d โหวต", votes)
				else string.format("คลิกโหวต • %d โหวต", votes)
			badge.BackgroundColor3 = if isSelectedByMe
				then Color3.fromRGB(32, 138, 76)
				else Color3.fromRGB(15, 19, 30)
			badge.TextColor3 = if isSelectedByMe
				then Color3.fromRGB(255, 255, 255)
				else Color3.fromRGB(205, 218, 242)
		end

		local stroke = btn:FindFirstChild("CardStroke") :: UIStroke?
		if stroke then
			stroke.Thickness = if isSelectedByMe then 2.6 else 1.5
			stroke.Transparency = if isSelectedByMe then 0 else 0.45
		end
	end
end

local function ownsSkinClient(skinId: string): boolean
	if skinId == "Default" then
		return true
	end
	local ownedStr = tostring(localPlayer:GetAttribute("OwnedSkins") or "Default")
	for _, token in string.split(ownedStr, ",") do
		if token == skinId then
			return true
		end
	end
	return false
end

local function refreshShopAndQuests()
	updateHeaderCoins()

	local hasSpeed = localPlayer:GetAttribute("HasSpeedPerk") == true
	local hasHealth = localPlayer:GetAttribute("HasHealthPerk") == true
	local isAfk = localPlayer:GetAttribute("IsAFK") == true
	local soundPack = tostring(localPlayer:GetAttribute("TauntSoundPack") or "Classic")
	local equippedSkin = tostring(localPlayer:GetAttribute("EquippedSkin") or "Default")

	afkToggleBtn.Text = if isAfk then "💤 พักอยู่ (กดเล่น)" else "💤 พัก (AFK)"
	afkToggleBtn.BackgroundColor3 = if isAfk then Color3.fromRGB(148, 88, 24) else Color3.fromRGB(36, 44, 64)
	afkToggleBtn.TextColor3 = if isAfk then Color3.fromRGB(255, 232, 135) else Color3.fromRGB(205, 220, 245)
	afkStroke.Color = if isAfk then Color3.fromRGB(255, 200, 75) else Color3.fromRGB(95, 120, 168)

	speedActionPill.Text = if hasSpeed then "✓ เปิดใช้งานแล้ว!" else "💰 ซื้อถาวร 30 Coins"
	speedActionPill.BackgroundColor3 = if hasSpeed then Color3.fromRGB(28, 118, 68) else Color3.fromRGB(15, 20, 32)
	speedActionPill.TextColor3 = if hasSpeed then Color3.fromRGB(165, 255, 195) else Color3.fromRGB(255, 220, 80)

	healthActionPill.Text = if hasHealth then "✓ เปิดใช้งานแล้ว!" else "💰 ซื้อถาวร 40 Coins"
	healthActionPill.BackgroundColor3 = if hasHealth then Color3.fromRGB(28, 118, 68) else Color3.fromRGB(15, 20, 32)
	healthActionPill.TextColor3 = if hasHealth then Color3.fromRGB(165, 255, 195) else Color3.fromRGB(255, 220, 80)

	soundActionPill.Text = "🔊 โหมด: " .. soundPack .. " (คลิกเปลี่ยน)"
	soundActionPill.TextColor3 = Color3.fromRGB(255, 225, 110)

	local equippedSkinName = "ปกติ"
	for _, skin in SKIN_OPTIONS do
		if skin.Id == equippedSkin then
			equippedSkinName = skin.Name
		end
		local sBtn = skinButtonsById[skin.Id]
		if not sBtn then
			continue
		end
		local owned = ownsSkinClient(skin.Id)
		local isEquipped = (equippedSkin == skin.Id)

		local statusLbl = sBtn:FindFirstChild("Status") :: TextLabel?
		if statusLbl then
			if isEquipped then
				statusLbl.Text = "✓ กำลังใส่อยู่"
				statusLbl.BackgroundColor3 = Color3.fromRGB(30, 128, 72)
				statusLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
			elseif owned then
				statusLbl.Text = "กดสวมใส่"
				statusLbl.BackgroundColor3 = Color3.fromRGB(36, 62, 108)
				statusLbl.TextColor3 = Color3.fromRGB(205, 232, 255)
			else
				statusLbl.Text = string.format("💰 %d Coins", skin.Cost)
				statusLbl.BackgroundColor3 = Color3.fromRGB(15, 20, 32)
				statusLbl.TextColor3 = Color3.fromRGB(255, 215, 75)
			end
		end

		local stroke = sBtn:FindFirstChild("Stroke") :: UIStroke?
		if stroke then
			stroke.Thickness = if isEquipped then 2.6 else 1.5
			stroke.Transparency = if isEquipped then 0 else 0.38
		end
	end

	-- Update Quest Progress Bars
	local qMorph = math.clamp((localPlayer:GetAttribute("Quest_MorphCount") :: number?) or 0, 0, 5)
	local qTaunt = math.clamp((localPlayer:GetAttribute("Quest_TauntCount") :: number?) or 0, 0, 3)
	local qCatch = math.clamp((localPlayer:GetAttribute("Quest_CatchCount") :: number?) or 0, 0, 1)

	local completedQuests = 0
	for _, qData in {
		{ Key = "Morph", Cur = qMorph, Max = 5 },
		{ Key = "Taunt", Cur = qTaunt, Max = 3 },
		{ Key = "Catch", Cur = qCatch, Max = 1 },
	} do
		if qData.Cur >= qData.Max then
			completedQuests += 1
		end
		local ref = questRefs[qData.Key]
		if ref then
			local done = qData.Cur >= qData.Max
			ref.CountLabel.Text = if done then "✓ สำเร็จ!" else string.format("%d / %d", qData.Cur, qData.Max)
			ref.CountLabel.TextColor3 = if done then Color3.fromRGB(105, 255, 145) else Color3.fromRGB(235, 242, 255)
			TweenService:Create(ref.FillBar, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = UDim2.fromScale(qData.Cur / qData.Max, 1),
			}):Play()
		end
	end

	local perkTag = if hasSpeed and hasHealth
		then "👟+🛡️ ครบเซ็ต"
		elseif hasSpeed then "👟 วิ่งไว"
		elseif hasHealth then "🛡️ เกราะ +50HP"
		else "ยังไม่มี Perk"

	quickLoadoutLabel.Text = string.format(
		"✨ สกิน: %s   |   ⚡ Perk: %s   |   🔊 เสียง: %s   |   📋 ภารกิจสำเร็จ: %d/3",
		equippedSkinName,
		perkTag,
		soundPack,
		completedQuests
	)
end

local function rebuildPlayerRoster()
	for _, child in rosterList:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	local allPlayers = Players:GetPlayers()
	rosterTitle.Text = string.format("🏆 อันดับผู้เล่นในเซิร์ฟเวอร์ (%d คน)", #allPlayers)

	for key, sb in sortButtons do
		local isSel = (key == currentLeaderboardMode)
		sb.BackgroundColor3 = if isSel then Color3.fromRGB(48, 115, 215) else Color3.fromRGB(30, 38, 56)
		sb.TextColor3 = if isSel then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(175, 190, 218)
	end

	if currentLeaderboardMode == "Wins" then
		table.sort(allPlayers, function(a, b)
			return getStat(a, "Wins") > getStat(b, "Wins")
		end)
	elseif currentLeaderboardMode == "Survival" then
		table.sort(allPlayers, function(a, b)
			return getStat(a, "BestSurvival") > getStat(b, "BestSurvival")
		end)
	else
		table.sort(allPlayers, function(a, b)
			return getStat(a, "Coins") > getStat(b, "Coins")
		end)
	end

	for idx, p in allPlayers do
		local isMe = (p == localPlayer)
		local row = Instance.new("Frame")
		row.Name = p.Name
		row.Size = UDim2.new(1, -8, 0, 52)
		row.LayoutOrder = idx
		row.BackgroundColor3 = if isMe then Color3.fromRGB(32, 44, 68) else Color3.fromRGB(26, 32, 48)
		row.BorderSizePixel = 0
		row.ZIndex = 34
		row.Parent = rosterList
		addCorner(row, 12)
		addBorderStroke(
			row,
			if idx == 1 then Color3.fromRGB(255, 205, 70) elseif isMe then Color3.fromRGB(85, 175, 255) else Color3.fromRGB(52, 66, 96),
			1.2,
			if idx == 1 or isMe then 0.25 else 0.55
		)

		local rankBadge = Instance.new("TextLabel")
		rankBadge.Size = UDim2.fromOffset(38, 30)
		rankBadge.Position = UDim2.new(0, 10, 0.5, 0)
		rankBadge.AnchorPoint = Vector2.new(0, 0.5)
		rankBadge.BackgroundTransparency = 1
		rankBadge.Font = Enum.Font.GothamBlack
		rankBadge.TextSize = 15
		rankBadge.TextColor3 = if idx == 1
			then Color3.fromRGB(255, 215, 70)
			elseif idx == 2 then Color3.fromRGB(210, 220, 235)
			elseif idx == 3 then Color3.fromRGB(225, 150, 95)
			else Color3.fromRGB(150, 168, 198)
		rankBadge.Text = if idx == 1 then "🥇" elseif idx == 2 then "🥈" elseif idx == 3 then "🥉" else string.format("#%d", idx)
		rankBadge.ZIndex = 35
		rankBadge.Parent = row

		local avatarImg = Instance.new("ImageLabel")
		avatarImg.Size = UDim2.fromOffset(36, 36)
		avatarImg.Position = UDim2.new(0, 52, 0.5, 0)
		avatarImg.AnchorPoint = Vector2.new(0, 0.5)
		avatarImg.BackgroundColor3 = Color3.fromRGB(42, 50, 72)
		avatarImg.ZIndex = 35
		avatarImg.Parent = row
		addCorner(avatarImg, 99)
		addBorderStroke(avatarImg, Color3.fromRGB(110, 175, 255), 1.2, 0.3)

		task.spawn(function()
			local ok, content = pcall(function()
				return Players:GetUserThumbnailAsync(
					p.UserId,
					Enum.ThumbnailType.HeadShot,
					Enum.ThumbnailSize.Size48x48
				)
			end)
			if ok and avatarImg.Parent then
				avatarImg.Image = content
			end
		end)

		local nameLbl = Instance.new("TextLabel")
		nameLbl.Size = UDim2.new(0.42, 0, 0, 20)
		nameLbl.Position = UDim2.fromOffset(98, 7)
		nameLbl.BackgroundTransparency = 1
		nameLbl.Font = Enum.Font.GothamBlack
		nameLbl.TextSize = 13
		nameLbl.TextXAlignment = Enum.TextXAlignment.Left
		nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
		nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLbl.Text = p.DisplayName .. (if isMe then " (คุณ)" else "")
		nameLbl.ZIndex = 35
		nameLbl.Parent = row

		local roleName = if p:GetAttribute("IsAFK") == true
			then "💤 พัก (AFK)"
			elseif p.Team and p.Team.Name == "Hiders" then "🟦 กำลังซ่อน"
			elseif p.Team and p.Team.Name == "Seekers" then "🟥 กำลังล่า"
			else "🟢 พร้อมในล็อบบี้"

		local roleLbl = Instance.new("TextLabel")
		roleLbl.Size = UDim2.new(0.42, 0, 0, 16)
		roleLbl.Position = UDim2.fromOffset(98, 27)
		roleLbl.BackgroundTransparency = 1
		roleLbl.Font = Enum.Font.GothamMedium
		roleLbl.TextSize = 11
		roleLbl.TextXAlignment = Enum.TextXAlignment.Left
		roleLbl.TextColor3 = Color3.fromRGB(165, 185, 218)
		roleLbl.Text = roleName
		roleLbl.ZIndex = 35
		roleLbl.Parent = row

		local winsVal = getStat(p, "Wins")
		local survVal = getStat(p, "BestSurvival")
		local coinVal = getStat(p, "Coins")

		local statsRight = Instance.new("TextLabel")
		statsRight.Size = UDim2.fromOffset(275, 36)
		statsRight.Position = UDim2.new(1, -14, 0.5, 0)
		statsRight.AnchorPoint = Vector2.new(1, 0.5)
		statsRight.BackgroundTransparency = 1
		statsRight.Font = Enum.Font.GothamBold
		statsRight.TextSize = 12
		statsRight.TextXAlignment = Enum.TextXAlignment.Right
		statsRight.TextColor3 = Color3.fromRGB(255, 220, 85)
		statsRight.Text = string.format("🏆 %d ชนะ   •   ⏱️ %ds   •   💰 %d C", winsVal, survVal, coinVal)
		statsRight.ZIndex = 35
		statsRight.Parent = row
	end
end

for key, sb in sortButtons do
	sb.Activated:Connect(function()
		currentLeaderboardMode = key :: "Wins" | "Survival" | "Coins"
		rebuildPlayerRoster()
	end)
end

local function updateStartButtonState()
	local roundState = workspace:GetAttribute("RoundState")
	local rawTimer = workspace:GetAttribute("RoundTimer")
	local timerNum = if typeof(rawTimer) == "number" then math.max(0, math.ceil(rawTimer)) else 0
	local isAfk = localPlayer:GetAttribute("IsAFK") == true

	if roundState == "Intermission" then
		startGameBtn.Active = false
		startBtnGrad.Color = ColorSequence.new(Color3.fromRGB(245, 168, 42), Color3.fromRGB(195, 108, 22))
		startBtnStroke.Color = Color3.fromRGB(255, 228, 125)
		startGameBtn.Text = string.format("⏳ เริ่มในอีก %d วินาที...", timerNum)
	elseif roundState == "HidingPhase" or roundState == "HuntingPhase" or roundState == "RoundOver" then
		startGameBtn.Active = false
		startBtnGrad.Color = ColorSequence.new(Color3.fromRGB(68, 76, 98), Color3.fromRGB(45, 52, 70))
		startBtnStroke.Color = Color3.fromRGB(115, 130, 160)
		startGameBtn.Text = "🎮 กำลังแข่งขันรอบนี้"
	elseif isAfk then
		startGameBtn.Active = true
		startBtnGrad.Color = ColorSequence.new(Color3.fromRGB(58, 222, 112), Color3.fromRGB(24, 152, 72))
		startBtnStroke.Color = Color3.fromRGB(150, 255, 185)
		startGameBtn.Text = "▶ ยกเลิก AFK & เริ่มเกม"
	else
		startGameBtn.Active = true
		startBtnGrad.Color = ColorSequence.new(Color3.fromRGB(58, 222, 112), Color3.fromRGB(24, 152, 72))
		startBtnStroke.Color = Color3.fromRGB(150, 255, 185)
		startGameBtn.Text = "▶ เริ่มเกม (โหวต 30 วิ)"
	end
end

--------------------------------------------------------------------------------
-- LOBBY WAITING BGM PLAYLIST (Energetic Instrumental Only, Auto-Cycles & Fades)
--------------------------------------------------------------------------------
local lobbyBgmMuted = false
local currentBgmIndex = 1

local lobbyBgmSound = SoundService:FindFirstChild("LobbyWaitingBgm") :: Sound?
if not lobbyBgmSound then
	lobbyBgmSound = Instance.new("Sound")
	lobbyBgmSound.Name = "LobbyWaitingBgm"
	lobbyBgmSound.Looped = false
	lobbyBgmSound.Volume = 0
	lobbyBgmSound.Parent = SoundService
end

local function updateBgmButtonVisual()
	if lobbyBgmMuted then
		bgmToggleBtn.Text = "🔇 ปิดเพลง"
		bgmToggleBtn.TextColor3 = Color3.fromRGB(185, 195, 215)
		bgmStroke.Color = Color3.fromRGB(95, 110, 140)
	else
		bgmToggleBtn.Text = string.format("🎵 มันส์ %d/%d", currentBgmIndex, #LOBBY_BGM_TRACKS)
		bgmToggleBtn.TextColor3 = Color3.fromRGB(145, 235, 185)
		bgmStroke.Color = Color3.fromRGB(95, 215, 150)
	end
end

local function playCurrentLobbyTrack()
	if not lobbyBgmSound then
		return
	end
	local track = LOBBY_BGM_TRACKS[currentBgmIndex] or LOBBY_BGM_TRACKS[1]
	if lobbyBgmSound.SoundId ~= track.Id then
		lobbyBgmSound:Stop()
		lobbyBgmSound.SoundId = track.Id
		lobbyBgmSound.TimePosition = 0
	end
	if not lobbyBgmSound.IsPlaying then
		lobbyBgmSound:Play()
	end
	TweenService:Create(lobbyBgmSound, TweenInfo.new(0.6), { Volume = LOBBY_BGM_VOLUME }):Play()
	updateBgmButtonVisual()
end

local function syncLobbyBgmPlayback()
	if not lobbyBgmSound then
		return
	end
	local isLobbyTeam = not localPlayer.Team or localPlayer.Team.Name == "Lobby"
	local shouldPlay = isLobbyTeam and not lobbyBgmMuted

	if shouldPlay then
		playCurrentLobbyTrack()
	else
		TweenService:Create(lobbyBgmSound, TweenInfo.new(0.55), { Volume = 0 }):Play()
		task.delay(0.6, function()
			if lobbyBgmSound and (lobbyBgmMuted or (localPlayer.Team and localPlayer.Team.Name ~= "Lobby")) then
				lobbyBgmSound:Pause()
			end
		end)
		updateBgmButtonVisual()
	end
end

-- Auto-advance to the next energetic instrumental track when one finishes!
if lobbyBgmSound then
	lobbyBgmSound.Ended:Connect(function()
		local isLobbyTeam = not localPlayer.Team or localPlayer.Team.Name == "Lobby"
		if isLobbyTeam and not lobbyBgmMuted then
			currentBgmIndex = (currentBgmIndex % #LOBBY_BGM_TRACKS) + 1
			playCurrentLobbyTrack()
		end
	end)
end

task.spawn(function()
	local soundsToPreload: { Instance } = {}
	for _, tr in LOBBY_BGM_TRACKS do
		local tmp = Instance.new("Sound")
		tmp.SoundId = tr.Id
		table.insert(soundsToPreload, tmp)
	end
	pcall(function()
		ContentProvider:PreloadAsync(soundsToPreload)
	end)
	for _, inst in soundsToPreload do
		inst:Destroy()
	end
	syncLobbyBgmPlayback()
end)

-- Click button to cycle Track 1 -> Track 2 -> Track 3 -> Track 4 -> Mute -> Track 1!
bgmToggleBtn.Activated:Connect(function()
	if lobbyBgmMuted then
		lobbyBgmMuted = false
		currentBgmIndex = 1
	elseif currentBgmIndex < #LOBBY_BGM_TRACKS then
		currentBgmIndex += 1
	else
		lobbyBgmMuted = true
	end
	syncLobbyBgmPlayback()
end)

updateBgmButtonVisual()

local function setDashboardOpen(isOpen: boolean)
	mainCard.Visible = isOpen
	backdropDim.Visible = isOpen
	localPlayer:SetAttribute("LobbyMenuOpen", isOpen)
	if lobbyBlur then
		TweenService:Create(lobbyBlur, TweenInfo.new(0.22), {
			Size = if isOpen then 10 else 0,
		}):Play()
	end
end

local function updateLobbyVisibility()
	local isLobbyTeam = not localPlayer.Team or localPlayer.Team.Name == "Lobby"
	local roundState = workspace:GetAttribute("RoundState")
	local roundStatus = workspace:GetAttribute("RoundStatus")

	if typeof(roundStatus) == "string" and roundStatus ~= "" then
		local dot = if roundState == "Intermission" then "🟠 " else "🟢 "
		subStatusLabel.Text = dot .. roundStatus .. "  •  มองทะลุกระจกชมแมพจริงด้านล่างได้!"
	end

	updateStartButtonState()
	syncLobbyBgmPlayback()

	if not isLobbyTeam then
		openLobbyBtn.Visible = false
		setDashboardOpen(false)
		manuallyMinimized = false
		return
	end

	if (roundState == "WaitingForPlayers" or roundState == "Intermission" or roundState == nil) and not manuallyMinimized then
		setDashboardOpen(true)
		openLobbyBtn.Visible = false
	else
		setDashboardOpen(false)
		openLobbyBtn.Visible = true
	end
end

minimizeBtn.Activated:Connect(function()
	manuallyMinimized = true
	setDashboardOpen(false)
	openLobbyBtn.Visible = true
end)

openLobbyBtn.Activated:Connect(function()
	manuallyMinimized = false
	setDashboardOpen(true)
	openLobbyBtn.Visible = false
	rebuildPlayerRoster()
	refreshShopAndQuests()
	updateMapVoteUI()
end)

-- Bind leaderstats Coins/Wins live updates
local function bindLeaderstats(ls: Instance)
	local coinsObj = ls:WaitForChild("Coins", 5) :: IntValue?
	if coinsObj then
		coinsObj.Changed:Connect(updateHeaderCoins)
	end
	local winsObj = ls:WaitForChild("Wins", 5) :: IntValue?
	if winsObj then
		winsObj.Changed:Connect(rebuildPlayerRoster)
	end
	updateHeaderCoins()
end

local existingLs = localPlayer:FindFirstChild("leaderstats")
if existingLs then
	task.spawn(bindLeaderstats, existingLs)
end
localPlayer.ChildAdded:Connect(function(child)
	if child.Name == "leaderstats" then
		task.spawn(bindLeaderstats, child)
	end
end)

-- Connect Signals
Players.PlayerAdded:Connect(rebuildPlayerRoster)
Players.PlayerRemoving:Connect(rebuildPlayerRoster)
localPlayer:GetPropertyChangedSignal("Team"):Connect(function()
	updateLobbyVisibility()
	rebuildPlayerRoster()
end)
localPlayer:GetAttributeChangedSignal("HasSpeedPerk"):Connect(refreshShopAndQuests)
localPlayer:GetAttributeChangedSignal("HasHealthPerk"):Connect(refreshShopAndQuests)
localPlayer:GetAttributeChangedSignal("OwnedSkins"):Connect(refreshShopAndQuests)
localPlayer:GetAttributeChangedSignal("EquippedSkin"):Connect(refreshShopAndQuests)
localPlayer:GetAttributeChangedSignal("IsAFK"):Connect(function()
	refreshShopAndQuests()
	updateStartButtonState()
	rebuildPlayerRoster()
end)
localPlayer:GetAttributeChangedSignal("TauntSoundPack"):Connect(refreshShopAndQuests)
localPlayer:GetAttributeChangedSignal("Quest_MorphCount"):Connect(refreshShopAndQuests)
localPlayer:GetAttributeChangedSignal("Quest_TauntCount"):Connect(refreshShopAndQuests)
localPlayer:GetAttributeChangedSignal("Quest_CatchCount"):Connect(refreshShopAndQuests)
localPlayer:GetAttributeChangedSignal("VotedMap"):Connect(updateMapVoteUI)

for _, opt in MAP_OPTIONS do
	workspace:GetAttributeChangedSignal("Votes_" .. opt.Id):Connect(updateMapVoteUI)
end
workspace:GetAttributeChangedSignal("SelectedMapChoice"):Connect(updateMapVoteUI)
workspace:GetAttributeChangedSignal("ActiveMapId"):Connect(updateMapVoteUI)

workspace:GetAttributeChangedSignal("RoundState"):Connect(function()
	updateLobbyVisibility()
	rebuildPlayerRoster()
	updateMapVoteUI()
end)
workspace:GetAttributeChangedSignal("RoundTimer"):Connect(updateStartButtonState)
workspace:GetAttributeChangedSignal("RoundStatus"):Connect(updateLobbyVisibility)

task.spawn(function()
	while true do
		if mainCard.Visible and activeTab == "Leaderboard" then
			rebuildPlayerRoster()
		end
		task.wait(3)
	end
end)

switchTab("Maps")
rebuildPlayerRoster()
refreshShopAndQuests()
updateMapVoteUI()
updateLobbyVisibility()
