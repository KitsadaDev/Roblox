--!strict
-- StarterPlayerScripts/Client/LobbyUi.client.luau
-- Procedurally creates a modern, interactive Lobby Waiting Screen & Map Voting Dashboard:
-- 1. Map Voting / Selection Panel: Choose between all 4 themed maps OR "สุ่มแมพ (Random Map)" before the round starts!
-- 2. Live Player Roster: Shows player avatars, names, teams, and Coins
-- 3. How to Play Guide & Coins Perk Shop (Speed Boost & +50 Max HP)
-- 4. Can be minimized/toggled anytime with "เมนูหน้าล็อบบี้ / เลือกแมพ" so players can walk around the 3D Sky Lounge

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui

local PropRemotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PropRemotes"))
local abilityRequestEvent = PropRemotes.AbilityRequest
local voteMapEvent = PropRemotes.VoteMapRequest

--------------------------------------------------------------------------------
-- MAP OPTIONS CONFIGURATION
--------------------------------------------------------------------------------
type MapOption = {
	Id: string,
	Title: string,
	Sub: string,
	Color: Color3,
}

local MAP_OPTIONS: { MapOption } = {
	{
		Id = "GrandPlaza",
		Title = "1. ออฟฟิศ & อาร์เคด",
		Sub = "สำนักงาน ห้องสมุด & โกดัง",
		Color = Color3.fromRGB(80, 185, 255),
	},
	{
		Id = "CyberpunkMall",
		Title = "2. ห้างไซเบอร์พังก์",
		Sub = "เมืองนีออน & ห้องเซิร์ฟเวอร์",
		Color = Color3.fromRGB(235, 70, 210),
	},
	{
		Id = "SchoolCampus",
		Title = "3. โรงเรียนมัธยม",
		Sub = "ห้องเรียน โรงอาหาร & โรงยิม",
		Color = Color3.fromRGB(255, 175, 65),
	},
	{
		Id = "CampingPark",
		Title = "4. แคมป์ปิ้งพาร์ค",
		Sub = "เต็นท์ กองไฟ & ป่าสนยามเย็น",
		Color = Color3.fromRGB(85, 215, 115),
	},
	{
		Id = "Random",
		Title = "สุ่มแมพ (Random)",
		Sub = "สุ่มจากทั้ง 4 แมพอัตโนมัติ!",
		Color = Color3.fromRGB(255, 215, 75),
	},
}

local MAP_NAMES_BY_ID: { [string]: string } = {
	GrandPlaza = "1. ออฟฟิศ & อาร์เคดพลาซ่า",
	CyberpunkMall = "2. ห้างไซเบอร์พังก์นีออน",
	SchoolCampus = "3. โรงเรียนมัธยม",
	CampingPark = "4. แคมป์ปิ้งพาร์คยามเย็น",
	Random = "สุ่มแมพ (Random)",
}

--------------------------------------------------------------------------------
-- CREATE LOBBY SCREENGUI
--------------------------------------------------------------------------------
local existing = playerGui:FindFirstChild("PropHuntLobbyGui")
if existing then
	existing:Destroy()
end

local lobbyGui = Instance.new("ScreenGui")
lobbyGui.Name = "PropHuntLobbyGui"
lobbyGui.ResetOnSpawn = false
lobbyGui.IgnoreGuiInset = true
lobbyGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
lobbyGui.Parent = playerGui

local function styleCard(frame: Frame, bgColor: Color3, radius: number, strokeColor: Color3?, strokeTrans: number?)
	frame.BackgroundColor3 = bgColor
	frame.BorderSizePixel = 0

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = frame

	if strokeColor then
		local stroke = Instance.new("UIStroke")
		stroke.Color = strokeColor
		stroke.Thickness = 1.5
		stroke.Transparency = strokeTrans or 0.25
		stroke.Parent = frame
	end
end

-- Top-Left Button to Toggle the Lobby Dashboard while in Lobby
local openLobbyBtn = Instance.new("TextButton")
openLobbyBtn.Name = "ToggleLobbyMenuBtn"
openLobbyBtn.Size = UDim2.new(0, 185, 0, 40)
openLobbyBtn.Position = UDim2.new(0, 20, 0, 74)
openLobbyBtn.BackgroundColor3 = Color3.fromRGB(26, 30, 44)
openLobbyBtn.Font = Enum.Font.GothamBold
openLobbyBtn.TextSize = 14
openLobbyBtn.TextColor3 = Color3.fromRGB(255, 215, 80)
openLobbyBtn.Text = "เลือกแมพ / เมนูหน้าล็อบบี้"
openLobbyBtn.ZIndex = 25
openLobbyBtn.Parent = lobbyGui

local openBtnCorner = Instance.new("UICorner")
openBtnCorner.CornerRadius = UDim.new(0, 10)
openBtnCorner.Parent = openLobbyBtn

local openBtnStroke = Instance.new("UIStroke")
openBtnStroke.Color = Color3.fromRGB(255, 205, 70)
openBtnStroke.Thickness = 1.5
openBtnStroke.Transparency = 0.25
openBtnStroke.Parent = openLobbyBtn

--------------------------------------------------------------------------------
-- MAIN LOBBY DASHBOARD CARD (Center Screen)
--------------------------------------------------------------------------------
local mainCard = Instance.new("Frame")
mainCard.Name = "LobbyDashboard"
mainCard.Size = UDim2.new(0, 760, 0, 470)
mainCard.Position = UDim2.fromScale(0.5, 0.53)
mainCard.AnchorPoint = Vector2.new(0.5, 0.5)
mainCard.BackgroundTransparency = 0.05
mainCard.ZIndex = 30
styleCard(mainCard, Color3.fromRGB(18, 21, 30), 16, Color3.fromRGB(85, 175, 255), 0.2)
mainCard.Parent = lobbyGui

-- Header Banner
local headerFrame = Instance.new("Frame")
headerFrame.Name = "Header"
headerFrame.Size = UDim2.new(1, -32, 0, 64)
headerFrame.Position = UDim2.new(0, 16, 0, 14)
headerFrame.ZIndex = 31
styleCard(headerFrame, Color3.fromRGB(26, 32, 48), 12, Color3.fromRGB(70, 95, 140), 0.4)
headerFrame.Parent = mainCard

local gameTitle = Instance.new("TextLabel")
gameTitle.Size = UDim2.new(0.62, -20, 0, 30)
gameTitle.Position = UDim2.new(0, 16, 0, 6)
gameTitle.BackgroundTransparency = 1
gameTitle.Font = Enum.Font.GothamBlack
gameTitle.TextSize = 22
gameTitle.TextXAlignment = Enum.TextXAlignment.Left
gameTitle.TextColor3 = Color3.fromRGB(255, 215, 75)
gameTitle.Text = "PROP HUNT PLAZA : โหวตแมพ & เตรียมพร้อม"
gameTitle.ZIndex = 32
gameTitle.Parent = headerFrame

local subStatusLabel = Instance.new("TextLabel")
subStatusLabel.Size = UDim2.new(0.68, -20, 0, 22)
subStatusLabel.Position = UDim2.new(0, 16, 0, 36)
subStatusLabel.BackgroundTransparency = 1
subStatusLabel.Font = Enum.Font.GothamMedium
subStatusLabel.TextSize = 13
subStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
subStatusLabel.TextColor3 = Color3.fromRGB(175, 195, 225)
subStatusLabel.Text = "เลือกโหวตแมพด้านล่างได้เลย! (มองทะลุกระจกดูแมพจริงได้)"
subStatusLabel.ZIndex = 32
subStatusLabel.Parent = headerFrame

local afkToggleBtn = Instance.new("TextButton")
afkToggleBtn.Name = "AfkToggleButton"
afkToggleBtn.Size = UDim2.new(0, 118, 0, 38)
afkToggleBtn.Position = UDim2.new(1, -184, 0.5, 0)
afkToggleBtn.AnchorPoint = Vector2.new(1, 0.5)
afkToggleBtn.BackgroundColor3 = Color3.fromRGB(45, 52, 72)
afkToggleBtn.Font = Enum.Font.GothamBold
afkToggleBtn.TextSize = 12
afkToggleBtn.TextColor3 = Color3.fromRGB(115, 245, 145)
afkToggleBtn.Text = "🟢 พร้อมเล่น"
afkToggleBtn.ZIndex = 32
afkToggleBtn.Parent = headerFrame

local afkCorner = Instance.new("UICorner")
afkCorner.CornerRadius = UDim.new(0, 8)
afkCorner.Parent = afkToggleBtn

afkToggleBtn.Activated:Connect(function()
	abilityRequestEvent:FireServer("ToggleAFK")
end)

local minimizeBtn = Instance.new("TextButton")
minimizeBtn.Name = "WalkAroundButton"
minimizeBtn.Size = UDim2.new(0, 162, 0, 38)
minimizeBtn.Position = UDim2.new(1, -14, 0.5, 0)
minimizeBtn.AnchorPoint = Vector2.new(1, 0.5)
minimizeBtn.BackgroundColor3 = Color3.fromRGB(55, 155, 95)
minimizeBtn.Font = Enum.Font.GothamBold
minimizeBtn.TextSize = 12
minimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
minimizeBtn.Text = "เดินชมล็อบบี้ (ย่อ)"
minimizeBtn.ZIndex = 32
minimizeBtn.Parent = headerFrame

local minCorner = Instance.new("UICorner")
minCorner.CornerRadius = UDim.new(0, 8)
minCorner.Parent = minimizeBtn

--------------------------------------------------------------------------------
-- MAP SELECTION / VOTING SECTION (5 Map Cards: 4 Maps + Random)
--------------------------------------------------------------------------------
local mapVotePanel = Instance.new("Frame")
mapVotePanel.Name = "MapVotingPanel"
mapVotePanel.Size = UDim2.new(1, -32, 0, 138)
mapVotePanel.Position = UDim2.new(0, 16, 0, 88)
mapVotePanel.ZIndex = 31
styleCard(mapVotePanel, Color3.fromRGB(23, 27, 40), 12, Color3.fromRGB(85, 175, 255), 0.35)
mapVotePanel.Parent = mainCard

local mapVoteHeader = Instance.new("TextLabel")
mapVoteHeader.Size = UDim2.new(1, -24, 0, 24)
mapVoteHeader.Position = UDim2.new(0, 12, 0, 8)
mapVoteHeader.BackgroundTransparency = 1
mapVoteHeader.Font = Enum.Font.GothamBlack
mapVoteHeader.TextSize = 14
mapVoteHeader.TextXAlignment = Enum.TextXAlignment.Left
mapVoteHeader.TextColor3 = Color3.fromRGB(255, 215, 75)
mapVoteHeader.Text = "เลือกแมพก่อนเริ่มเกม (โหวตได้ 4 แมพ หรือเลือกสุ่มแมพ)"
mapVoteHeader.ZIndex = 32
mapVoteHeader.Parent = mapVotePanel

local mapButtonsById: { [string]: TextButton } = {}

for idx, opt in MAP_OPTIONS do
	local cardWidthScale = 0.188
	local xPosScale = 0.012 + (idx - 1) * 0.196

	local mBtn = Instance.new("TextButton")
	mBtn.Name = "MapBtn_" .. opt.Id
	mBtn.Size = UDim2.new(cardWidthScale, 0, 0, 92)
	mBtn.Position = UDim2.new(xPosScale, 0, 0, 36)
	mBtn.BackgroundColor3 = Color3.fromRGB(30, 35, 50)
	mBtn.Text = ""
	mBtn.ZIndex = 32
	mBtn.Parent = mapVotePanel

	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 10)
	c.Parent = mBtn

	local stroke = Instance.new("UIStroke")
	stroke.Name = "CardStroke"
	stroke.Color = opt.Color
	stroke.Thickness = 1.5
	stroke.Transparency = 0.45
	stroke.Parent = mBtn

	local titleLbl = Instance.new("TextLabel")
	titleLbl.Name = "Title"
	titleLbl.Size = UDim2.new(1, -12, 0, 22)
	titleLbl.Position = UDim2.new(0, 6, 0, 6)
	titleLbl.BackgroundTransparency = 1
	titleLbl.Font = Enum.Font.GothamBlack
	titleLbl.TextSize = 12
	titleLbl.TextColor3 = opt.Color
	titleLbl.Text = opt.Title
	titleLbl.TextTruncate = Enum.TextTruncate.AtEnd
	titleLbl.ZIndex = 33
	titleLbl.Parent = mBtn

	local subLbl = Instance.new("TextLabel")
	subLbl.Name = "Sub"
	subLbl.Size = UDim2.new(1, -12, 0, 32)
	subLbl.Position = UDim2.new(0, 6, 0, 28)
	subLbl.BackgroundTransparency = 1
	subLbl.Font = Enum.Font.GothamMedium
	subLbl.TextSize = 11
	subLbl.TextWrapped = true
	subLbl.TextColor3 = Color3.fromRGB(210, 220, 235)
	subLbl.Text = opt.Sub
	subLbl.ZIndex = 33
	subLbl.Parent = mBtn

	local voteBadge = Instance.new("TextLabel")
	voteBadge.Name = "VoteBadge"
	voteBadge.Size = UDim2.new(1, -12, 0, 20)
	voteBadge.Position = UDim2.new(0, 6, 1, -24)
	voteBadge.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
	voteBadge.Font = Enum.Font.GothamBold
	voteBadge.TextSize = 11
	voteBadge.TextColor3 = Color3.fromRGB(255, 255, 255)
	voteBadge.Text = "0 โหวต"
	voteBadge.ZIndex = 33
	voteBadge.Parent = mBtn

	local vbCorner = Instance.new("UICorner")
	vbCorner.CornerRadius = UDim.new(0, 6)
	vbCorner.Parent = voteBadge

	mBtn.Activated:Connect(function()
		voteMapEvent:FireServer(opt.Id)
	end)

	mapButtonsById[opt.Id] = mBtn
end

--------------------------------------------------------------------------------
-- BOTTOM LEFT: LIVE PLAYER ROSTER & LEADERBOARD (เรียงตามผู้เล่น / ชนะ / รอดชีวิต)
--------------------------------------------------------------------------------
local rosterPanel = Instance.new("Frame")
rosterPanel.Name = "RosterPanel"
rosterPanel.Size = UDim2.new(0, 265, 0, 218)
rosterPanel.Position = UDim2.new(0, 16, 0, 236)
rosterPanel.ZIndex = 31
styleCard(rosterPanel, Color3.fromRGB(24, 28, 40), 12, Color3.fromRGB(60, 70, 95), 0.4)
rosterPanel.Parent = mainCard

local rosterTitle = Instance.new("TextLabel")
rosterTitle.Size = UDim2.new(0.46, 0, 0, 24)
rosterTitle.Position = UDim2.new(0, 10, 0, 6)
rosterTitle.BackgroundTransparency = 1
rosterTitle.Font = Enum.Font.GothamBlack
rosterTitle.TextSize = 13
rosterTitle.TextXAlignment = Enum.TextXAlignment.Left
rosterTitle.TextColor3 = Color3.fromRGB(110, 200, 255)
rosterTitle.Text = "อันดับผู้เล่น"
rosterTitle.ZIndex = 32
rosterTitle.Parent = rosterPanel

local currentLeaderboardMode: "Roster" | "Wins" | "Survival" = "Wins"

local modeToggleBtn = Instance.new("TextButton")
modeToggleBtn.Size = UDim2.new(0.50, -10, 0, 22)
modeToggleBtn.Position = UDim2.new(1, -8, 0, 7)
modeToggleBtn.AnchorPoint = Vector2.new(1, 0)
modeToggleBtn.BackgroundColor3 = Color3.fromRGB(36, 44, 64)
modeToggleBtn.Font = Enum.Font.GothamBold
modeToggleBtn.TextSize = 11
modeToggleBtn.TextColor3 = Color3.fromRGB(255, 215, 75)
modeToggleBtn.Text = "🏆 ชนะเยอะสุด"
modeToggleBtn.ZIndex = 33
modeToggleBtn.Parent = rosterPanel

local modeBtnCorner = Instance.new("UICorner")
modeBtnCorner.CornerRadius = UDim.new(0, 6)
modeBtnCorner.Parent = modeToggleBtn

local rosterList = Instance.new("ScrollingFrame")
rosterList.Name = "PlayerList"
rosterList.Size = UDim2.new(1, -20, 1, -42)
rosterList.Position = UDim2.new(0, 10, 0, 36)
rosterList.BackgroundTransparency = 1
rosterList.BorderSizePixel = 0
rosterList.ScrollBarThickness = 4
rosterList.CanvasSize = UDim2.new(0, 0, 0, 0)
rosterList.AutomaticCanvasSize = Enum.AutomaticSize.Y
rosterList.ZIndex = 32
rosterList.Parent = rosterPanel

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 6)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = rosterList

--------------------------------------------------------------------------------
-- BOTTOM RIGHT: HOW TO PLAY, PERK SHOP & COSMETIC PROP SKINS
--------------------------------------------------------------------------------
local rightPanel = Instance.new("Frame")
rightPanel.Name = "RightPanel"
rightPanel.Size = UDim2.new(1, -307, 0, 218)
rightPanel.Position = UDim2.new(0, 291, 0, 236)
rightPanel.BackgroundTransparency = 1
rightPanel.ZIndex = 31
rightPanel.Parent = mainCard

-- Quick Rules & Live Daily Quests Summary
local guideCard = Instance.new("Frame")
guideCard.Size = UDim2.new(1, 0, 0, 68)
guideCard.Position = UDim2.new(0, 0, 0, 0)
guideCard.ZIndex = 32
styleCard(guideCard, Color3.fromRGB(24, 32, 48), 10, Color3.fromRGB(75, 185, 255), 0.35)
guideCard.Parent = rightPanel

local guideText = Instance.new("TextLabel")
guideText.Size = UDim2.new(1, -135, 1, -10)
guideText.Position = UDim2.new(0, 10, 0, 5)
guideText.BackgroundTransparency = 1
guideText.Font = Enum.Font.GothamMedium
guideText.TextSize = 11
guideText.TextWrapped = true
guideText.TextXAlignment = Enum.TextXAlignment.Left
guideText.TextYAlignment = Enum.TextYAlignment.Center
guideText.TextColor3 = Color3.fromRGB(225, 235, 250)
guideText.Text = "📋 ภารกิจรับเหรียญฟรี:\n• แปลงร่าง 5 ครั้ง (+25C) | ผิวปาก 3 ครั้ง (+30C) | จับ Hider 1 คน (+35C)"
guideText.ZIndex = 33
guideText.Parent = guideCard

local soundPackBtn = Instance.new("TextButton")
soundPackBtn.Name = "TauntSoundPackBtn"
soundPackBtn.Size = UDim2.new(0, 115, 0, 48)
soundPackBtn.Position = UDim2.new(1, -10, 0.5, 0)
soundPackBtn.AnchorPoint = Vector2.new(1, 0.5)
soundPackBtn.BackgroundColor3 = Color3.fromRGB(36, 44, 66)
soundPackBtn.Font = Enum.Font.GothamBold
soundPackBtn.TextSize = 11
soundPackBtn.TextWrapped = true
soundPackBtn.TextColor3 = Color3.fromRGB(255, 215, 80)
soundPackBtn.Text = "🔊 เสียง Taunt:\nClassic"
soundPackBtn.ZIndex = 33
soundPackBtn.Parent = guideCard

local spCorner = Instance.new("UICorner")
spCorner.CornerRadius = UDim.new(0, 8)
spCorner.Parent = soundPackBtn

soundPackBtn.Activated:Connect(function()
	abilityRequestEvent:FireServer("CycleTauntPack")
end)

-- Lobby Perk & Cosmetics Shop Section
local shopCard = Instance.new("Frame")
shopCard.Size = UDim2.new(1, 0, 0, 142)
shopCard.Position = UDim2.new(0, 0, 0, 76)
shopCard.ZIndex = 32
styleCard(shopCard, Color3.fromRGB(24, 28, 40), 12, Color3.fromRGB(255, 205, 70), 0.35)
shopCard.Parent = rightPanel

local shopHeader = Instance.new("TextLabel")
shopHeader.Size = UDim2.new(1, -24, 0, 20)
shopHeader.Position = UDim2.new(0, 12, 0, 5)
shopHeader.BackgroundTransparency = 1
shopHeader.Font = Enum.Font.GothamBlack
shopHeader.TextSize = 12
shopHeader.TextXAlignment = Enum.TextXAlignment.Left
shopHeader.TextColor3 = Color3.fromRGB(255, 215, 75)
shopHeader.Text = "ร้านค้า Perk & สกิน Prop พิเศษ (ใช้ Coins)"
shopHeader.ZIndex = 33
shopHeader.Parent = shopCard

local function createShopButton(
	title: string,
	subText: string,
	xScale: number,
	accentCol: Color3,
	onClick: () -> ()
): TextButton
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0.47, 0, 0, 48)
	btn.Position = UDim2.new(xScale, 0, 0, 27)
	btn.BackgroundColor3 = Color3.fromRGB(32, 38, 54)
	btn.Text = ""
	btn.ZIndex = 33
	btn.Parent = shopCard

	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 8)
	c.Parent = btn

	local s = Instance.new("UIStroke")
	s.Color = accentCol
	s.Thickness = 1.5
	s.Transparency = 0.3
	s.Parent = btn

	local tLabel = Instance.new("TextLabel")
	tLabel.Name = "Title"
	tLabel.Size = UDim2.new(1, -12, 0, 18)
	tLabel.Position = UDim2.new(0, 6, 0, 4)
	tLabel.BackgroundTransparency = 1
	tLabel.Font = Enum.Font.GothamBlack
	tLabel.TextSize = 12
	tLabel.TextColor3 = accentCol
	tLabel.Text = title
	tLabel.ZIndex = 34
	tLabel.Parent = btn

	local dLabel = Instance.new("TextLabel")
	dLabel.Name = "Sub"
	dLabel.Size = UDim2.new(1, -12, 0, 22)
	dLabel.Position = UDim2.new(0, 6, 0, 22)
	dLabel.BackgroundTransparency = 1
	dLabel.Font = Enum.Font.GothamBold
	dLabel.TextSize = 10
	dLabel.TextWrapped = true
	dLabel.TextColor3 = Color3.fromRGB(230, 235, 245)
	dLabel.Text = subText
	dLabel.ZIndex = 34
	dLabel.Parent = btn

	btn.Activated:Connect(onClick)
	return btn
end

local speedPerkBtn = createShopButton(
	"รองเท้าวิ่งไว (+Speed)",
	"ความเร็ว 20 (30 Coins)",
	0.02,
	Color3.fromRGB(80, 220, 255),
	function()
		abilityRequestEvent:FireServer("BuySpeedPerk")
	end
)

local healthPerkBtn = createShopButton(
	"เกราะเพิ่มเลือด (+50 HP)",
	"เลือด 150 HP (40 Coins)",
	0.51,
	Color3.fromRGB(95, 240, 130),
	function()
		abilityRequestEvent:FireServer("BuyHealthPerk")
	end
)

type SkinOption = {
	Id: string,
	Name: string,
	Cost: number,
	Color: Color3,
}

local SKIN_OPTIONS: { SkinOption } = {
	{ Id = "Default", Name = "ปกติ", Cost = 0, Color = Color3.fromRGB(185, 195, 210) },
	{ Id = "GoldProp", Name = "ทองคำ ✨", Cost = 100, Color = Color3.fromRGB(255, 205, 55) },
	{ Id = "NeonCyan", Name = "นีออนฟ้า", Cost = 150, Color = Color3.fromRGB(0, 235, 255) },
	{ Id = "RubySparkle", Name = "ทับทิม ✨", Cost = 200, Color = Color3.fromRGB(255, 70, 105) },
	{ Id = "GhostForceField", Name = "วิญญาณ", Cost = 250, Color = Color3.fromRGB(155, 215, 255) },
}

local skinButtonsById: { [string]: TextButton } = {}

for idx, skin in SKIN_OPTIONS do
	local widthScale = 0.184
	local xScale = 0.02 + (idx - 1) * 0.194

	local sBtn = Instance.new("TextButton")
	sBtn.Name = "Skin_" .. skin.Id
	sBtn.Size = UDim2.new(widthScale, 0, 0, 52)
	sBtn.Position = UDim2.new(xScale, 0, 0, 82)
	sBtn.BackgroundColor3 = Color3.fromRGB(30, 35, 50)
	sBtn.Text = ""
	sBtn.ZIndex = 33
	sBtn.Parent = shopCard

	local sc = Instance.new("UICorner")
	sc.CornerRadius = UDim.new(0, 8)
	sc.Parent = sBtn

	local ss = Instance.new("UIStroke")
	ss.Name = "Stroke"
	ss.Color = skin.Color
	ss.Thickness = 1.5
	ss.Transparency = 0.35
	ss.Parent = sBtn

	local sTitle = Instance.new("TextLabel")
	sTitle.Name = "Title"
	sTitle.Size = UDim2.new(1, -6, 0, 20)
	sTitle.Position = UDim2.new(0, 3, 0, 5)
	sTitle.BackgroundTransparency = 1
	sTitle.Font = Enum.Font.GothamBlack
	sTitle.TextSize = 11
	sTitle.TextColor3 = skin.Color
	sTitle.Text = skin.Name
	sTitle.ZIndex = 34
	sTitle.Parent = sBtn

	local sSub = Instance.new("TextLabel")
	sSub.Name = "Status"
	sSub.Size = UDim2.new(1, -6, 0, 20)
	sSub.Position = UDim2.new(0, 3, 0, 26)
	sSub.BackgroundTransparency = 1
	sSub.Font = Enum.Font.GothamBold
	sSub.TextSize = 10
	sSub.TextColor3 = Color3.fromRGB(230, 235, 245)
	sSub.Text = if skin.Cost == 0 then "ฟรี" else string.format("%d C", skin.Cost)
	sSub.ZIndex = 34
	sSub.Parent = sBtn

	sBtn.Activated:Connect(function()
		abilityRequestEvent:FireServer("BuyOrEquipSkin", skin.Id)
	end)

	skinButtonsById[skin.Id] = sBtn
end

--------------------------------------------------------------------------------
-- REACTIVE UPDATES (MAP VOTES, ROSTER, STATUS & VISIBILITY)
--------------------------------------------------------------------------------
local manuallyMinimized = false

local function updateMapVoteUI()
	local myVote = localPlayer:GetAttribute("VotedMap") or "Random"
	local leadingChoice = workspace:GetAttribute("SelectedMapChoice") or "Random"
	local activeMapId = workspace:GetAttribute("ActiveMapId") or "GrandPlaza"

	local leadingName = MAP_NAMES_BY_ID[tostring(leadingChoice)] or "สุ่มแมพ (Random)"
	local activeName = MAP_NAMES_BY_ID[tostring(activeMapId)] or tostring(activeMapId)
	mapVoteHeader.Text = string.format(
		"เลือกแมพก่อนเริ่มเกม  |  โหวตนำ: %s  |  แมพด้านล่าง: %s",
		leadingName,
		activeName
	)

	for _, opt in MAP_OPTIONS do
		local btn = mapButtonsById[opt.Id]
		if not btn then
			continue
		end

		local countAttr = workspace:GetAttribute("Votes_" .. opt.Id)
		local votes = if typeof(countAttr) == "number" then countAttr else 0
		local isSelectedByMe = (myVote == opt.Id)

		local badge = btn:FindFirstChild("VoteBadge") :: TextLabel?
		if badge then
			badge.Text = if isSelectedByMe
				then string.format("✓ เลือกแล้ว (%d)", votes)
				else string.format("%d โหวต", votes)
			badge.BackgroundColor3 = if isSelectedByMe
				then Color3.fromRGB(45, 125, 75)
				else Color3.fromRGB(20, 24, 34)
		end

		local stroke = btn:FindFirstChild("CardStroke") :: UIStroke?
		if stroke then
			stroke.Thickness = if isSelectedByMe then 2.8 else 1.5
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

local function refreshPerkButtons()
	local hasSpeed = localPlayer:GetAttribute("HasSpeedPerk") == true
	local hasHealth = localPlayer:GetAttribute("HasHealthPerk") == true
	local isAfk = localPlayer:GetAttribute("IsAFK") == true
	local soundPack = tostring(localPlayer:GetAttribute("TauntSoundPack") or "Classic")

	afkToggleBtn.Text = if isAfk then "💤 พัก (AFK)" else "🟢 พร้อมเล่น"
	afkToggleBtn.TextColor3 = if isAfk then Color3.fromRGB(255, 185, 75) else Color3.fromRGB(115, 245, 145)
	soundPackBtn.Text = "🔊 เสียง Taunt:\n" .. soundPack

	local qMorph = math.min(5, (localPlayer:GetAttribute("Quest_MorphCount") :: number?) or 0)
	local qTaunt = math.min(3, (localPlayer:GetAttribute("Quest_TauntCount") :: number?) or 0)
	local qCatch = math.min(1, (localPlayer:GetAttribute("Quest_CatchCount") :: number?) or 0)
	guideText.Text = string.format(
		"📋 ภารกิจรายวัน: แปลงร่าง (%d/5) +25C | ผิวปาก (%d/3) +30C | จับ Hider (%d/1) +35C\n• Prop เล็ก HP 70 / ใหญ่ HP 140 | Seeker มี [Q] Radar & [E] Surge (+15C/Kill)",
		qMorph,
		qTaunt,
		qCatch
	)

	local speedSub = speedPerkBtn:FindFirstChild("Sub") :: TextLabel?
	if speedSub then
		speedSub.Text = if hasSpeed then "✓ ใช้งานอยู่!" else "ความเร็ว 20 (30 C)"
	end

	local healthSub = healthPerkBtn:FindFirstChild("Sub") :: TextLabel?
	if healthSub then
		healthSub.Text = if hasHealth then "✓ ใช้งานอยู่!" else "เลือด 150 HP (40 C)"
	end

	local equippedSkin = tostring(localPlayer:GetAttribute("EquippedSkin") or "Default")
	for _, skin in SKIN_OPTIONS do
		local sBtn = skinButtonsById[skin.Id]
		if not sBtn then
			continue
		end
		local owned = ownsSkinClient(skin.Id)
		local isEquipped = (equippedSkin == skin.Id)

		local statusLbl = sBtn:FindFirstChild("Status") :: TextLabel?
		if statusLbl then
			if isEquipped then
				statusLbl.Text = "✓ ใส่อยู่"
				statusLbl.TextColor3 = Color3.fromRGB(95, 255, 140)
			elseif owned then
				statusLbl.Text = "กดใส่"
				statusLbl.TextColor3 = Color3.fromRGB(200, 225, 255)
			else
				statusLbl.Text = string.format("%d C", skin.Cost)
				statusLbl.TextColor3 = Color3.fromRGB(255, 215, 75)
			end
		end

		local stroke = sBtn:FindFirstChild("Stroke") :: UIStroke?
		if stroke then
			stroke.Thickness = if isEquipped then 2.5 else 1.5
			stroke.Transparency = if isEquipped then 0 else 0.35
		end
	end
end

local function rebuildPlayerRoster()
	for _, child in rosterList:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	local allPlayers = Players:GetPlayers()
	rosterTitle.Text = string.format("ผู้เล่น (%d คน)", #allPlayers)

	local function getStat(p: Player, statName: string): number
		local ls = p:FindFirstChild("leaderstats")
		local valObj = ls and ls:FindFirstChild(statName) :: IntValue?
		return if valObj then valObj.Value else 0
	end

	if currentLeaderboardMode == "Wins" then
		modeToggleBtn.Text = "🏆 ชนะเยอะสุด"
		table.sort(allPlayers, function(a, b)
			return getStat(a, "Wins") > getStat(b, "Wins")
		end)
	elseif currentLeaderboardMode == "Survival" then
		modeToggleBtn.Text = "⏱️ ซ่อนรอดนานสุด"
		table.sort(allPlayers, function(a, b)
			return getStat(a, "BestSurvival") > getStat(b, "BestSurvival")
		end)
	else
		modeToggleBtn.Text = "💰 เหรียญเยอะสุด"
		table.sort(allPlayers, function(a, b)
			return getStat(a, "Coins") > getStat(b, "Coins")
		end)
	end

	for idx, p in allPlayers do
		local row = Instance.new("Frame")
		row.Name = p.Name
		row.Size = UDim2.new(1, -6, 0, 42)
		row.LayoutOrder = idx
		row.ZIndex = 33
		styleCard(row, Color3.fromRGB(32, 36, 50), 8)
		row.Parent = rosterList

		local avatarImg = Instance.new("ImageLabel")
		avatarImg.Size = UDim2.new(0, 30, 0, 30)
		avatarImg.Position = UDim2.new(0, 6, 0.5, 0)
		avatarImg.AnchorPoint = Vector2.new(0, 0.5)
		avatarImg.BackgroundColor3 = Color3.fromRGB(45, 50, 68)
		avatarImg.ZIndex = 34
		avatarImg.Parent = row

		local imgCorner = Instance.new("UICorner")
		imgCorner.CornerRadius = UDim.new(1, 0)
		imgCorner.Parent = avatarImg

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
		nameLbl.Size = UDim2.new(1, -110, 0, 18)
		nameLbl.Position = UDim2.new(0, 42, 0, 4)
		nameLbl.BackgroundTransparency = 1
		nameLbl.Font = Enum.Font.GothamBold
		nameLbl.TextSize = 12
		nameLbl.TextXAlignment = Enum.TextXAlignment.Left
		nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
		nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLbl.Text = string.format("#%d %s", idx, p.DisplayName)
		nameLbl.ZIndex = 34
		nameLbl.Parent = row

		local winsVal = getStat(p, "Wins")
		local survVal = getStat(p, "BestSurvival")
		local coinVal = getStat(p, "Coins")

		local roleName = if p.Team then p.Team.Name else "Lobby"
		local roleLbl = Instance.new("TextLabel")
		roleLbl.Size = UDim2.new(1, -110, 0, 15)
		roleLbl.Position = UDim2.new(0, 42, 0, 22)
		roleLbl.BackgroundTransparency = 1
		roleLbl.Font = Enum.Font.GothamMedium
		roleLbl.TextSize = 10
		roleLbl.TextXAlignment = Enum.TextXAlignment.Left
		roleLbl.TextColor3 = Color3.fromRGB(160, 175, 205)
		roleLbl.Text = string.format("%s | 🏆%d | ⏱️%ds", roleName, winsVal, survVal)
		roleLbl.ZIndex = 34
		roleLbl.Parent = row

		local rightText = if currentLeaderboardMode == "Wins"
			then string.format("🏆 %d", winsVal)
			elseif currentLeaderboardMode == "Survival" then string.format("⏱️ %ds", survVal)
			else string.format("%d C", coinVal)

		local coinLbl = Instance.new("TextLabel")
		coinLbl.Size = UDim2.new(0, 64, 1, 0)
		coinLbl.Position = UDim2.new(1, -8, 0, 0)
		coinLbl.AnchorPoint = Vector2.new(1, 0)
		coinLbl.BackgroundTransparency = 1
		coinLbl.Font = Enum.Font.GothamBold
		coinLbl.TextSize = 12
		coinLbl.TextXAlignment = Enum.TextXAlignment.Right
		coinLbl.TextColor3 = Color3.fromRGB(255, 215, 75)
		coinLbl.Text = rightText
		coinLbl.ZIndex = 34
		coinLbl.Parent = row
	end
end

modeToggleBtn.Activated:Connect(function()
	if currentLeaderboardMode == "Wins" then
		currentLeaderboardMode = "Survival"
	elseif currentLeaderboardMode == "Survival" then
		currentLeaderboardMode = "Roster"
	else
		currentLeaderboardMode = "Wins"
	end
	rebuildPlayerRoster()
end)

local function updateLobbyVisibility()
	local isLobbyTeam = not localPlayer.Team or localPlayer.Team.Name == "Lobby"
	local roundState = workspace:GetAttribute("RoundState")
	local roundStatus = workspace:GetAttribute("RoundStatus")

	if typeof(roundStatus) == "string" and roundStatus ~= "" then
		subStatusLabel.Text = "สถานะปัจจุบัน: " .. roundStatus .. "  |  คลิกเลือกแมพด้านล่างได้เลย!"
	end

	if not isLobbyTeam then
		openLobbyBtn.Visible = false
		mainCard.Visible = false
		manuallyMinimized = false
		return
	end

	openLobbyBtn.Visible = true

	if (roundState == "WaitingForPlayers" or roundState == "Intermission" or roundState == nil) and not manuallyMinimized then
		mainCard.Visible = true
	elseif manuallyMinimized then
		mainCard.Visible = false
	end
end

minimizeBtn.Activated:Connect(function()
	manuallyMinimized = true
	mainCard.Visible = false
end)

openLobbyBtn.Activated:Connect(function()
	manuallyMinimized = mainCard.Visible
	mainCard.Visible = not mainCard.Visible
	if mainCard.Visible then
		rebuildPlayerRoster()
		refreshPerkButtons()
		updateMapVoteUI()
	end
end)

-- Connect Signals
Players.PlayerAdded:Connect(rebuildPlayerRoster)
Players.PlayerRemoving:Connect(rebuildPlayerRoster)
localPlayer:GetPropertyChangedSignal("Team"):Connect(function()
	updateLobbyVisibility()
	rebuildPlayerRoster()
end)
localPlayer:GetAttributeChangedSignal("HasSpeedPerk"):Connect(refreshPerkButtons)
localPlayer:GetAttributeChangedSignal("HasHealthPerk"):Connect(refreshPerkButtons)
localPlayer:GetAttributeChangedSignal("OwnedSkins"):Connect(refreshPerkButtons)
localPlayer:GetAttributeChangedSignal("EquippedSkin"):Connect(refreshPerkButtons)
localPlayer:GetAttributeChangedSignal("IsAFK"):Connect(refreshPerkButtons)
localPlayer:GetAttributeChangedSignal("TauntSoundPack"):Connect(refreshPerkButtons)
localPlayer:GetAttributeChangedSignal("Quest_MorphCount"):Connect(refreshPerkButtons)
localPlayer:GetAttributeChangedSignal("Quest_TauntCount"):Connect(refreshPerkButtons)
localPlayer:GetAttributeChangedSignal("Quest_CatchCount"):Connect(refreshPerkButtons)
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
workspace:GetAttributeChangedSignal("RoundStatus"):Connect(updateLobbyVisibility)

task.spawn(function()
	while true do
		if mainCard.Visible then
			rebuildPlayerRoster()
		end
		task.wait(3)
	end
end)

rebuildPlayerRoster()
refreshPerkButtons()
updateMapVoteUI()
updateLobbyVisibility()
