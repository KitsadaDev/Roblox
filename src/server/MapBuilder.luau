--!strict
-- ServerScriptService/Server/MapBuilder.luau
-- Multi-Map Procedural Builder for Prop Hunt Plaza!
-- Supports 6 Distinct Maps + Permanent Sky Lounge Observation Lobby:
--   1. "GrandPlaza"      : อาคารสำนักงาน & อาร์เคดพลาซ่า (Office, Library, Arcade Lounge & Warehouse)
--   2. "CyberpunkMall"   : ห้างไซเบอร์พังก์นีออน (Futuristic Neon Mall, Server Room, Cyber Cafe & Hologram Plaza)
--   3. "SchoolCampus"    : โรงเรียนมัธยม (Classrooms, Cafeteria, Gymnasium & Library)
--   4. "CampingPark"     : แคมป์ปิ้งพาร์คยามเย็น (Forest Tents, Campfires, Picnic Area, Cabins & Creek Bridge)
--   5. "JapaneseVillage" : หมู่บ้านซากุระญี่ปุ่น (Torii Gates, Koi Pond Bridge, Tea House, Ramen Street & Sakura Grove)
--   6. "MedievalCastle"  : ปราสาทยุคกลาง (Castle Courtyard, Royal Banquet Hall, Wizard Library & Blacksmith Armory)

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")

local MapBuilder = {}

export type MapId =
	"GrandPlaza"
	| "CyberpunkMall"
	| "SchoolCampus"
	| "CampingPark"
	| "JapaneseVillage"
	| "MedievalCastle"

MapBuilder.MAP_LIST = {
	{
		Id = "GrandPlaza",
		Title = "1. ออฟฟิศ & อาร์เคดพลาซ่า",
		Subtitle = "สำนักงาน ห้องสมุด โกดัง และคาเฟ่อาร์เคด",
	},
	{
		Id = "CyberpunkMall",
		Title = "2. ห้างไซเบอร์พังก์นีออน",
		Subtitle = "เมืองอนาคต ตู้โฮโลแกรม ห้องเซิร์ฟเวอร์ และบาร์นีออน",
	},
	{
		Id = "SchoolCampus",
		Title = "3. โรงเรียนมัธยมศึกษา",
		Subtitle = "ห้องเรียน โรงอาหาร โรงยิม และห้องสมุด",
	},
	{
		Id = "CampingPark",
		Title = "4. แคมป์ปิ้งพาร์คยามเย็น",
		Subtitle = "เต็นท์แคมป์ปิ้ง กองไฟ ลำธาร และป่าสน",
	},
	{
		Id = "JapaneseVillage",
		Title = "5. หมู่บ้านซากุระญี่ปุ่น",
		Subtitle = "เสาโทริอิ สระปลาคราฟ ร้านราเมง และสวนซากุระ",
	},
	{
		Id = "MedievalCastle",
		Title = "6. ปราสาทยุคกลาง",
		Subtitle = "ลานปราสาท ห้องโถงราชา หอเวทมนตร์ และโรงตีเหล็ก",
	},
}

local MORPH_TAG = "Morphable"
local FLOOR_Y = 0
local MAP_SIZE = 240
local WALL_HEIGHT = 30
local WALL_THICKNESS = 2

-- Helper to create anchored parts cleanly
local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = props.Material or Enum.Material.SmoothPlastic
	p.Color = props.Color or Color3.fromRGB(200, 200, 200)
	p.Size = props.Size or Vector3.new(1, 1, 1)
	if props.Transparency then
		p.Transparency = props.Transparency
	end
	if props.CanCollide ~= nil then
		p.CanCollide = props.CanCollide
	end
	if props.CanQuery ~= nil then
		p.CanQuery = props.CanQuery
	end
	if props.CastShadow ~= nil then
		p.CastShadow = props.CastShadow
	end
	if props.Shape then
		p.Shape = props.Shape
	end
	if props.CFrame then
		p.CFrame = props.CFrame
	elseif props.Position then
		p.Position = props.Position
	end
	p.Name = props.Name or "Part"
	p.Parent = props.Parent
	return p
end

-- Places a multi-part prop Model upright on the floor while preserving internal part rotations
local function placeMorphableProp(model: Model, parent: Instance, groundPos: Vector3, yawDeg: number)
	local bboxCF, bboxSize = model:GetBoundingBox()
	local bottomY = bboxCF.Position.Y - (bboxSize.Y * 0.5)

	local currentPivot = model:GetPivot()
	local pivotOffsetY = currentPivot.Position.Y - bottomY

	local deltaPos = Vector3.new(
		groundPos.X - currentPivot.Position.X,
		(groundPos.Y + pivotOffsetY) - currentPivot.Position.Y,
		groundPos.Z - currentPivot.Position.Z
	)
	local rotatedPivot = CFrame.new(currentPivot.Position + deltaPos)
		* CFrame.Angles(0, math.rad(yawDeg), 0)
		* currentPivot.Rotation

	model:PivotTo(rotatedPivot)
	CollectionService:AddTag(model, MORPH_TAG)

	-- Add a ProximityPrompt so Hiders on PC ([E]) or Mobile (Tap) can easily morph into any nearby prop!
	local promptParent = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if promptParent and not promptParent:FindFirstChild("MorphPrompt") then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "MorphPrompt"
		prompt.ActionText = "แปลงร่าง (Morph)"
		prompt.ObjectText = string.gsub(model.Name, "_%d+$", "")
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 14
		prompt.RequiresLineOfSight = false
		prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
		prompt.Parent = promptParent
	end

	model.Parent = parent
end

-- Helper: Creates a realistic 3D metal-bezelled backlit architectural zone sign (non-morphable decor)
local function createZoneSign(
	parent: Instance,
	cf: CFrame,
	size: Vector3,
	text: string,
	bgColor: Color3,
	accentColor: Color3,
	textColor: Color3?
): Part
	local isThinBoard = size.Z <= 0.25

	if not isThinBoard then
		-- 3D Brushed Dark-Titanium Outer Bezel Housing + Top/Bottom Mounting Brackets
		part({
			Name = "ZoneSignBezel",
			Size = size + Vector3.new(0.55, 0.55, -0.18),
			CFrame = cf,
			Color = Color3.fromRGB(28, 32, 42),
			Material = Enum.Material.Metal,
			Parent = parent,
		})
		for _, sx in { -size.X * 0.36, size.X * 0.36 } do
			part({
				Name = "SignBracket",
				Size = Vector3.new(0.45, size.Y + 0.9, size.Z + 0.22),
				CFrame = cf * CFrame.new(sx, 0, 0),
				Color = Color3.fromRGB(40, 46, 58),
				Material = Enum.Material.Metal,
				Parent = parent,
			})
		end
	end

	local signPart = part({
		Name = "ZoneSign_" .. string.gsub(text, "%s+", ""),
		Size = size,
		CFrame = cf,
		Color = bgColor,
		Material = if isThinBoard then Enum.Material.SmoothPlastic else Enum.Material.Metal,
		Parent = parent,
	})

	if not isThinBoard then
		local glow = Instance.new("PointLight")
		glow.Color = accentColor
		glow.Brightness = 0.42
		glow.Range = 18
		glow.Parent = signPart
	end

	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		if isThinBoard and face == Enum.NormalId.Back then
			continue
		end

		local sg = Instance.new("SurfaceGui")
		sg.Face = face
		sg.LightInfluence = if isThinBoard then 0.22 else 0.1
		sg.MaxDistance = 240
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 48
		sg.Parent = signPart

		local outer = Instance.new("Frame")
		outer.Size = UDim2.new(1, -12, 1, -12)
		outer.Position = UDim2.fromOffset(6, 6)
		outer.BackgroundColor3 = bgColor
		outer.BorderSizePixel = 0
		outer.Parent = sg

		if not isThinBoard then
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0, 16)
			c.Parent = outer

			local grad = Instance.new("UIGradient")
			grad.Color = ColorSequence.new(
				bgColor:Lerp(Color3.fromRGB(255, 255, 255), 0.1),
				bgColor:Lerp(Color3.fromRGB(0, 0, 0), 0.28)
			)
			grad.Rotation = 90
			grad.Parent = outer

			local topBar = Instance.new("Frame")
			topBar.Size = UDim2.new(0.86, 0, 0, 5)
			topBar.Position = UDim2.new(0.5, 0, 0, 8)
			topBar.AnchorPoint = Vector2.new(0.5, 0)
			topBar.BackgroundColor3 = accentColor
			topBar.BorderSizePixel = 0
			topBar.Parent = outer
			local tc = Instance.new("UICorner")
			tc.CornerRadius = UDim.new(1, 0)
			tc.Parent = topBar
		end

		local stroke = Instance.new("UIStroke")
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Color = accentColor
		stroke.Thickness = if isThinBoard then 4 else 3.5
		stroke.Transparency = 0.12
		stroke.Parent = outer

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, -32, 0.72, 0)
		lbl.Position = UDim2.new(0, 16, if isThinBoard then 0.14 else 0.19, 0)
		lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.GothamBlack
		lbl.TextScaled = true
		lbl.TextColor3 = textColor or accentColor
		lbl.Text = text
		lbl.Parent = outer
	end

	return signPart
end

-- Helper: Adds a soft PointLight to a part
local function attachLight(target: BasePart, color: Color3, brightness: number, range: number)
	local pl = Instance.new("PointLight")
	pl.Color = color
	pl.Brightness = brightness
	pl.Range = range
	pl.Parent = target
end

--------------------------------------------------------------------------------
-- SHARED & THEMED MULTI-PART PROP MODEL BUILDERS (35 DESIGNS)
--------------------------------------------------------------------------------

-- 1. Detailed Shipping Crate
local function createCrateModel(scale: number?, mainCol: Color3?, trimCol: Color3?): Model
	local s = scale or 1
	local m = Instance.new("Model")
	m.Name = "ShippingCrate"

	local woodBase = mainCol or Color3.fromRGB(176, 128, 80)
	local woodFrame = trimCol or Color3.fromRGB(132, 88, 48)

	local core = part({
		Name = "Core",
		Size = Vector3.new(3.6, 3.6, 3.6) * s,
		Position = Vector3.new(0, 2 * s, 0),
		Color = woodBase,
		Material = Enum.Material.WoodPlanks,
		Parent = m,
	})

	for _, y in { 0.15 * s, 3.85 * s } do
		part({
			Name = "FrameCap",
			Size = Vector3.new(4.0, 0.3, 4.0) * s,
			Position = Vector3.new(0, y, 0),
			Color = woodFrame,
			Material = Enum.Material.Wood,
			Parent = m,
		})
	end

	for _, sx in { -1.82 * s, 1.82 * s } do
		for _, sz in { -1.82 * s, 1.82 * s } do
			part({
				Name = "CornerPost",
				Size = Vector3.new(0.36, 3.4, 0.36) * s,
				Position = Vector3.new(sx, 2.0 * s, sz),
				Color = woodFrame,
				Material = Enum.Material.Wood,
				Parent = m,
			})
		end
	end

	for _, zSide in { -1.85 * s, 1.85 * s } do
		part({
			Name = "DiagonalBraceZ",
			Size = Vector3.new(4.2, 0.28, 0.18) * s,
			CFrame = CFrame.new(0, 2.0 * s, zSide) * CFrame.Angles(0, 0, math.rad(45)),
			Color = woodFrame,
			Material = Enum.Material.Wood,
			Parent = m,
		})
	end

	m.PrimaryPart = core
	return m
end

-- 2. Industrial / Neon Barrel
local function createBarrelModel(mainColor: Color3, stripeColor: Color3?, isNeonStripe: boolean?): Model
	local m = Instance.new("Model")
	m.Name = "HazardBarrel"

	local base = part({
		Name = "BarrelCore",
		Size = Vector3.new(1.8, 4.0, 1.8),
		Position = Vector3.new(0, 2.1, 0),
		Transparency = 1,
		CanCollide = false,
		Parent = m,
	})

	part({
		Name = "Body",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(4.2, 2.7, 2.7),
		CFrame = CFrame.new(0, 2.1, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = mainColor,
		Material = Enum.Material.Metal,
		Parent = m,
	})

	if stripeColor then
		part({
			Name = "ColorBand",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.1, 2.74, 2.74),
			CFrame = CFrame.new(0, 2.1, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color = stripeColor,
			Material = if isNeonStripe then Enum.Material.Neon else Enum.Material.SmoothPlastic,
			Parent = m,
		})
	end

	for _, y in { 0.2, 1.45, 2.75, 4.0 } do
		part({
			Name = "RibRing",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.18, 2.86, 2.86),
			CFrame = CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(40, 44, 50),
			Material = Enum.Material.Metal,
			Parent = m,
		})
	end

	m.PrimaryPart = base
	return m
end

-- 3. Executive Computer Desk
local function createComputerDeskModel(screenCol: Color3?): Model
	local m = Instance.new("Model")
	m.Name = "ComputerDesk"

	local top = part({
		Name = "DeskTop",
		Size = Vector3.new(6.8, 0.35, 3.6),
		Position = Vector3.new(0, 3.0, 0),
		Color = Color3.fromRGB(165, 118, 78),
		Material = Enum.Material.Wood,
		Parent = m,
	})

	for _, sx in { -3.1, 3.1 } do
		part({
			Name = "SideLeg",
			Size = Vector3.new(0.3, 2.85, 3.2),
			Position = Vector3.new(sx, 1.425, 0),
			Color = Color3.fromRGB(45, 48, 55),
			Material = Enum.Material.Metal,
			Parent = m,
		})
	end
	part({
		Name = "BackModestyPanel",
		Size = Vector3.new(6.0, 1.6, 0.2),
		Position = Vector3.new(0, 2.0, -1.3),
		Color = Color3.fromRGB(55, 60, 68),
		Material = Enum.Material.Metal,
		Parent = m,
	})
	part({
		Name = "MonitorStand",
		Size = Vector3.new(0.8, 0.7, 0.6),
		Position = Vector3.new(-0.8, 3.5, -0.9),
		Color = Color3.fromRGB(35, 38, 42),
		Material = Enum.Material.Metal,
		Parent = m,
	})
	part({
		Name = "MonitorFrame",
		Size = Vector3.new(2.8, 1.7, 0.2),
		Position = Vector3.new(-0.8, 4.4, -0.85),
		Color = Color3.fromRGB(30, 32, 36),
		Material = Enum.Material.SmoothPlastic,
		Parent = m,
	})
	part({
		Name = "MonitorScreen",
		Size = Vector3.new(2.55, 1.45, 0.05),
		Position = Vector3.new(-0.8, 4.4, -0.73),
		Color = screenCol or Color3.fromRGB(85, 190, 255),
		Material = Enum.Material.Neon,
		Parent = m,
	})
	part({
		Name = "PCTower",
		Size = Vector3.new(0.9, 1.8, 1.8),
		Position = Vector3.new(2.1, 4.05, -0.4),
		Color = Color3.fromRGB(35, 38, 44),
		Material = Enum.Material.Metal,
		Parent = m,
	})
	part({
		Name = "PCStatusStrip",
		Size = Vector3.new(0.12, 1.3, 0.08),
		Position = Vector3.new(2.1, 4.05, 0.52),
		Color = screenCol or Color3.fromRGB(85, 190, 255),
		Material = Enum.Material.Neon,
		Parent = m,
	})
	part({
		Name = "Keyboard",
		Size = Vector3.new(1.8, 0.09, 0.65),
		Position = Vector3.new(-0.8, 3.22, 0.55),
		Color = Color3.fromRGB(36, 40, 46),
		Material = Enum.Material.SmoothPlastic,
		Parent = m,
	})
	part({
		Name = "MousePad",
		Size = Vector3.new(0.9, 0.04, 0.75),
		Position = Vector3.new(0.7, 3.2, 0.55),
		Color = Color3.fromRGB(48, 52, 62),
		Material = Enum.Material.Fabric,
		Parent = m,
	})
	part({
		Name = "CoffeeMug",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.42, 0.36, 0.36),
		CFrame = CFrame.new(-2.4, 3.38, 0.4) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(235, 232, 225),
		Material = Enum.Material.SmoothPlastic,
		Parent = m,
	})

	m.PrimaryPart = top
	return m
end

-- 4. Ergonomic Office Swivel Chair
local function createOfficeChairModel(fabricColor: Color3?): Model
	local m = Instance.new("Model")
	m.Name = "SwivelChair"
	local cColor = fabricColor or Color3.fromRGB(45, 115, 195)

	local seat = part({
		Name = "SeatCushion",
		Size = Vector3.new(2.1, 0.35, 2.1),
		Position = Vector3.new(0, 1.85, 0),
		Color = cColor,
		Material = Enum.Material.Fabric,
		Parent = m,
	})
	part({
		Name = "Backrest",
		Size = Vector3.new(2.0, 2.2, 0.32),
		Position = Vector3.new(0, 3.05, -0.92),
		Color = cColor,
		Material = Enum.Material.Fabric,
		Parent = m,
	})
	part({
		Name = "Piston",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.5, 0.35, 0.35),
		CFrame = CFrame.new(0, 0.95, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(45, 48, 52),
		Material = Enum.Material.Metal,
		Parent = m,
	})
	for _, angle in { 0, 90 } do
		part({
			Name = "WheelLeg",
			Size = Vector3.new(2.2, 0.2, 0.28),
			CFrame = CFrame.new(0, 0.15, 0) * CFrame.Angles(0, math.rad(angle), 0),
			Color = Color3.fromRGB(45, 48, 52),
			Material = Enum.Material.Metal,
			Parent = m,
		})
	end

	m.PrimaryPart = seat
	return m
end

-- 5. Plush Lounge Sofa
local function createSofaModel(sofaColor: Color3?): Model
	local m = Instance.new("Model")
	m.Name = "PlushSofa"
	local mainCol = sofaColor or Color3.fromRGB(165, 58, 65)

	local base = part({
		Name = "SofaBase",
		Size = Vector3.new(7.4, 1.1, 3.2),
		Position = Vector3.new(0, 0.75, 0),
		Color = mainCol,
		Material = Enum.Material.Fabric,
		Parent = m,
	})
	part({
		Name = "SofaBack",
		Size = Vector3.new(7.4, 2.1, 0.8),
		Position = Vector3.new(0, 2.15, -1.2),
		Color = mainCol,
		Material = Enum.Material.Fabric,
		Parent = m,
	})
	for _, sx in { -3.3, 3.3 } do
		part({
			Name = "Armrest",
			Size = Vector3.new(0.8, 1.6, 3.2),
			Position = Vector3.new(sx, 1.5, 0),
			Color = mainCol,
			Material = Enum.Material.Fabric,
			Parent = m,
		})
	end
	for _, sx in { -2.2, 2.2 } do
		part({
			Name = "ThrowPillow",
			Size = Vector3.new(1.1, 1.1, 0.45),
			CFrame = CFrame.new(sx, 1.85, -0.55) * CFrame.Angles(math.rad(-15), math.rad(sx * 5), 0),
			Color = Color3.fromRGB(235, 200, 95),
			Material = Enum.Material.Fabric,
			Parent = m,
		})
	end

	m.PrimaryPart = base
	return m
end

-- 6. Potted Indoor Plant
local function createPlantPotModel(leafColorOverride: Color3?): Model
	local m = Instance.new("Model")
	m.Name = "PottedPlant"

	local stem = part({
		Name = "MainStem",
		Size = Vector3.new(0.35, 2.2, 0.35),
		Position = Vector3.new(0, 2.8, 0),
		Color = Color3.fromRGB(85, 65, 42),
		Material = Enum.Material.Wood,
		Parent = m,
	})
	part({
		Name = "TerracottaPot",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.9, 1.9, 1.9),
		CFrame = CFrame.new(0, 0.95, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(190, 95, 62),
		Material = Enum.Material.Brick,
		Parent = m,
	})
	part({
		Name = "PotRim",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 2.15, 2.15),
		CFrame = CFrame.new(0, 1.8, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(190, 95, 62),
		Material = Enum.Material.Brick,
		Parent = m,
	})

	local baseGreen = leafColorOverride or Color3.fromRGB(62, 155, 75)
	for _, lf in {
		{ Pos = Vector3.new(0, 4.1, 0), Size = Vector3.new(2.5, 2.2, 2.5) },
		{ Pos = Vector3.new(0.8, 3.4, 0.6), Size = Vector3.new(1.8, 1.6, 1.8) },
		{ Pos = Vector3.new(-0.8, 3.5, -0.5), Size = Vector3.new(1.9, 1.6, 1.9) },
	} do
		part({
			Name = "Foliage",
			Shape = Enum.PartType.Ball,
			Size = lf.Size,
			Position = lf.Pos,
			Color = baseGreen,
			Material = Enum.Material.Grass,
			Parent = m,
		})
	end

	m.PrimaryPart = stem
	return m
end

-- 7. Vending Machine
local function createVendingMachineModel(themeColor: Color3?): Model
	local m = Instance.new("Model")
	m.Name = "VendingMachine"
	local cabColor = themeColor or Color3.fromRGB(205, 45, 50)

	local body = part({
		Name = "Cabinet",
		Size = Vector3.new(4.2, 7.6, 3.0),
		Position = Vector3.new(0, 3.8, 0),
		Color = cabColor,
		Material = Enum.Material.Metal,
		Parent = m,
	})
	part({
		Name = "DisplayWindow",
		Size = Vector3.new(2.6, 4.4, 0.15),
		Position = Vector3.new(-0.45, 4.6, 1.48),
		Color = Color3.fromRGB(125, 190, 230),
		Material = Enum.Material.Glass,
		Parent = m,
	})
	part({
		Name = "KeypadPanel",
		Size = Vector3.new(0.8, 2.8, 0.15),
		Position = Vector3.new(1.45, 4.6, 1.48),
		Color = Color3.fromRGB(35, 38, 44),
		Material = Enum.Material.Metal,
		Parent = m,
	})
	part({
		Name = "DispenseSlot",
		Size = Vector3.new(2.8, 1.1, 0.2),
		Position = Vector3.new(-0.35, 1.3, 1.46),
		Color = Color3.fromRGB(25, 28, 32),
		Material = Enum.Material.Metal,
		Parent = m,
	})

	m.PrimaryPart = body
	return m
end

-- 8. Retro Arcade Cabinet
local function createArcadeCabinetModel(accentColor: Color3?): Model
	local m = Instance.new("Model")
	m.Name = "ArcadeCabinet"
	local trim = accentColor or Color3.fromRGB(150, 55, 235)

	local lowerBox = part({
		Name = "CabinetBase",
		Size = Vector3.new(3.0, 3.8, 2.8),
		Position = Vector3.new(0, 1.9, 0),
		Color = Color3.fromRGB(30, 32, 40),
		Material = Enum.Material.SmoothPlastic,
		Parent = m,
	})
	part({
		Name = "UpperHood",
		Size = Vector3.new(3.0, 3.2, 2.2),
		Position = Vector3.new(0, 5.4, -0.3),
		Color = Color3.fromRGB(30, 32, 40),
		Material = Enum.Material.SmoothPlastic,
		Parent = m,
	})
	part({
		Name = "MarqueeSign",
		Size = Vector3.new(2.8, 0.7, 0.25),
		Position = Vector3.new(0, 6.55, 0.8),
		Color = trim,
		Material = Enum.Material.Neon,
		Parent = m,
	})
	part({
		Name = "ArcadeScreen",
		Size = Vector3.new(2.3, 1.9, 0.15),
		CFrame = CFrame.new(0, 5.0, 0.75) * CFrame.Angles(math.rad(-12), 0, 0),
		Color = Color3.fromRGB(70, 225, 180),
		Material = Enum.Material.Neon,
		Parent = m,
	})
	part({
		Name = "ControlDeck",
		Size = Vector3.new(2.8, 0.25, 1.1),
		Position = Vector3.new(0, 3.9, 0.95),
		Color = trim,
		Material = Enum.Material.SmoothPlastic,
		Parent = m,
	})
	part({
		Name = "JoystickBall",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(0.28, 0.28, 0.28),
		Position = Vector3.new(-0.75, 4.25, 1.0),
		Color = Color3.fromRGB(255, 65, 85),
		Material = Enum.Material.Neon,
		Parent = m,
	})
	for bIdx, bx in { 0.25, 0.65, 1.05 } do
		part({
			Name = "ArcadeBtn_" .. bIdx,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.12, 0.22, 0.22),
			CFrame = CFrame.new(bx, 4.08, 1.0) * CFrame.Angles(0, 0, math.rad(90)),
			Color = if bIdx % 2 == 0 then Color3.fromRGB(255, 220, 60) else Color3.fromRGB(60, 230, 255),
			Material = Enum.Material.Neon,
			Parent = m,
		})
	end
	for _, sx in { -1.48, 1.48 } do
		part({
			Name = "SideNeonTrim",
			Size = Vector3.new(0.1, 6.4, 0.14),
			Position = Vector3.new(sx, 3.4, 1.38),
			Color = trim,
			Material = Enum.Material.Neon,
			Parent = m,
		})
	end

	m.PrimaryPart = lowerBox
	return m
end

-- 9. Tall Library Bookshelf
local function createBookshelfModel(): Model
	local m = Instance.new("Model")
	m.Name = "LibraryBookshelf"
	local wood = Color3.fromRGB(118, 78, 48)

	local back = part({
		Name = "BackPanel",
		Size = Vector3.new(6.2, 8.2, 0.3),
		Position = Vector3.new(0, 4.1, -0.95),
		Color = wood,
		Material = Enum.Material.Wood,
		Parent = m,
	})
	for _, sx in { -2.95, 2.95 } do
		part({
			Name = "SideWall",
			Size = Vector3.new(0.3, 8.2, 2.2),
			Position = Vector3.new(sx, 4.1, 0),
			Color = wood,
			Material = Enum.Material.Wood,
			Parent = m,
		})
	end

	local palette = {
		Color3.fromRGB(195, 55, 55),
		Color3.fromRGB(55, 125, 200),
		Color3.fromRGB(65, 165, 90),
		Color3.fromRGB(220, 170, 55),
		Color3.fromRGB(145, 75, 185),
	}
	for idx, y in { 0.2, 2.2, 4.2, 6.2, 8.05 } do
		part({
			Name = "Shelf",
			Size = Vector3.new(5.6, 0.3, 2.0),
			Position = Vector3.new(0, y, 0.05),
			Color = wood,
			Material = Enum.Material.Wood,
			Parent = m,
		})
		if idx < 5 then
			for b = -2, 2 do
				part({
					Name = "BookCluster",
					Size = Vector3.new(0.85, 1.45, 1.25),
					Position = Vector3.new(b * 1.0, y + 0.85, 0.05),
					Color = palette[((idx + b) % #palette) + 1],
					Material = Enum.Material.SmoothPlastic,
					Parent = m,
				})
			end
		end
	end

	m.PrimaryPart = back
	return m
end

-- 10. Office Water Cooler
local function createWaterCoolerModel(): Model
	local m = Instance.new("Model")
	m.Name = "WaterCooler"

	local stand = part({
		Name = "DispenserStand",
		Size = Vector3.new(1.7, 3.2, 1.7),
		Position = Vector3.new(0, 1.6, 0),
		Color = Color3.fromRGB(238, 240, 245),
		Material = Enum.Material.SmoothPlastic,
		Parent = m,
	})
	part({
		Name = "WaterBottle",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.8, 1.45, 1.45),
		CFrame = CFrame.new(0, 4.1, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(70, 175, 255),
		Transparency = 0.25,
		Material = Enum.Material.Glass,
		Parent = m,
	})

	m.PrimaryPart = stand
	return m
end

-- 11. Traffic Cone
local function createTrafficConeModel(): Model
	local m = Instance.new("Model")
	m.Name = "TrafficCone"

	local base = part({
		Name = "ConeBase",
		Size = Vector3.new(1.5, 0.2, 1.5),
		Position = Vector3.new(0, 0.1, 0),
		Color = Color3.fromRGB(35, 35, 40),
		Material = Enum.Material.SmoothPlastic,
		Parent = m,
	})
	part({
		Name = "LowerCone",
		Size = Vector3.new(1.1, 0.9, 1.1),
		Position = Vector3.new(0, 0.65, 0),
		Color = Color3.fromRGB(255, 105, 25),
		Material = Enum.Material.SmoothPlastic,
		Parent = m,
	})
	part({
		Name = "ReflectiveBand",
		Size = Vector3.new(0.85, 0.45, 0.85),
		Position = Vector3.new(0, 1.32, 0),
		Color = Color3.fromRGB(245, 245, 250),
		Material = Enum.Material.SmoothPlastic,
		Parent = m,
	})
	part({
		Name = "ConeTip",
		Size = Vector3.new(0.55, 0.7, 0.55),
		Position = Vector3.new(0, 1.9, 0),
		Color = Color3.fromRGB(255, 105, 25),
		Material = Enum.Material.SmoothPlastic,
		Parent = m,
	})

	m.PrimaryPart = base
	return m
end

-- 12. Trash & Recycling Bin
local function createTrashBinModel(binColor: Color3?): Model
	local m = Instance.new("Model")
	m.Name = "TrashBin"
	local col = binColor or Color3.fromRGB(70, 82, 95)

	local lid = part({
		Name = "DomeLid",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.95, 1.1, 1.95),
		Position = Vector3.new(0, 2.5, 0),
		Color = Color3.fromRGB(45, 50, 58),
		Material = Enum.Material.SmoothPlastic,
		Parent = m,
	})
	part({
		Name = "BinCylinder",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2.5, 1.9, 1.9),
		CFrame = CFrame.new(0, 1.25, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = col,
		Material = Enum.Material.Metal,
		Parent = m,
	})

	m.PrimaryPart = lid
	return m
end

-- 13. Metal Filing Cabinet
local function createFilingCabinetModel(): Model
	local m = Instance.new("Model")
	m.Name = "FilingCabinet"

	local cab = part({
		Name = "CabinetBody",
		Size = Vector3.new(2.2, 4.6, 2.6),
		Position = Vector3.new(0, 2.3, 0),
		Color = Color3.fromRGB(130, 138, 148),
		Material = Enum.Material.Metal,
		Parent = m,
	})
	for _, y in { 0.85, 2.3, 3.75 } do
		part({
			Name = "DrawerFront",
			Size = Vector3.new(1.9, 1.25, 0.12),
			Position = Vector3.new(0, y, 1.32),
			Color = Color3.fromRGB(150, 158, 168),
			Material = Enum.Material.Metal,
			Parent = m,
		})
	end

	m.PrimaryPart = cab
	return m
end

-- 14. Cozy Floor Lamp
local function createFloorLampModel(shadeCol: Color3?): Model
	local m = Instance.new("Model")
	m.Name = "FloorLamp"

	local core = part({
		Name = "LampCore",
		Size = Vector3.new(0.5, 0.5, 0.5),
		Position = Vector3.new(0, 2.7, 0),
		Transparency = 1,
		CanCollide = false,
		Parent = m,
	})
	part({
		Name = "WeightedBase",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.25, 1.6, 1.6),
		CFrame = CFrame.new(0, 0.125, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(195, 160, 75),
		Material = Enum.Material.Metal,
		Parent = m,
	})
	part({
		Name = "StandPole",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(5.0, 0.22, 0.22),
		CFrame = CFrame.new(0, 2.7, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(195, 160, 75),
		Material = Enum.Material.Metal,
		Parent = m,
	})
	part({
		Name = "LampShade",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.5, 2.1, 2.1),
		CFrame = CFrame.new(0, 5.4, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = shadeCol or Color3.fromRGB(255, 235, 185),
		Material = Enum.Material.Neon,
		Parent = m,
	})

	m.PrimaryPart = core
	return m
end

-- 15. Cafe Round Table
local function createCafeTableModel(): Model
	local m = Instance.new("Model")
	m.Name = "CafeTable"

	local core = part({
		Name = "TableCore",
		Size = Vector3.new(1, 2.8, 1),
		Position = Vector3.new(0, 1.4, 0),
		Transparency = 1,
		CanCollide = false,
		Parent = m,
	})
	part({
		Name = "RoundTop",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 3.8, 3.8),
		CFrame = CFrame.new(0, 2.85, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(235, 230, 220),
		Material = Enum.Material.Marble,
		Parent = m,
	})
	part({
		Name = "CenterColumn",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2.6, 0.4, 0.4),
		CFrame = CFrame.new(0, 1.4, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(45, 48, 55),
		Material = Enum.Material.Metal,
		Parent = m,
	})
	part({
		Name = "BasePlate",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, 2.2, 2.2),
		CFrame = CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(45, 48, 55),
		Material = Enum.Material.Metal,
		Parent = m,
	})

	m.PrimaryPart = core
	return m
end

-- 16. Warehouse Pallet Stack
local function createPalletStackModel(): Model
	local m = Instance.new("Model")
	m.Name = "PalletBoxStack"

	local pallet = part({
		Name = "WoodPallet",
		Size = Vector3.new(4.4, 0.45, 4.4),
		Position = Vector3.new(0, 0.225, 0),
		Color = Color3.fromRGB(160, 118, 74),
		Material = Enum.Material.WoodPlanks,
		Parent = m,
	})
	part({
		Name = "CardboardBoxA",
		Size = Vector3.new(2.1, 2.0, 2.1),
		Position = Vector3.new(-0.9, 1.45, -0.8),
		Color = Color3.fromRGB(192, 148, 98),
		Material = Enum.Material.SmoothPlastic,
		Parent = m,
	})
	part({
		Name = "CardboardBoxB",
		Size = Vector3.new(1.9, 1.8, 2.0),
		Position = Vector3.new(1.1, 1.35, -0.7),
		Color = Color3.fromRGB(182, 138, 88),
		Material = Enum.Material.SmoothPlastic,
		Parent = m,
	})
	part({
		Name = "TopBox",
		Size = Vector3.new(1.8, 1.5, 1.8),
		CFrame = CFrame.new(-0.3, 3.2, -0.6) * CFrame.Angles(0, math.rad(15), 0),
		Color = Color3.fromRGB(185, 140, 92),
		Material = Enum.Material.SmoothPlastic,
		Parent = m,
	})

	m.PrimaryPart = pallet
	return m
end

-- 17. NEW (Cyberpunk Map): Server Rack & Hologram Terminal
local function createServerRackModel(neonColor: Color3?): Model
	local m = Instance.new("Model")
	m.Name = "CyberServerRack"
	local glow = neonColor or Color3.fromRGB(0, 240, 255)

	local body = part({
		Name = "RackCabinet",
		Size = Vector3.new(3.2, 7.8, 3.2),
		Position = Vector3.new(0, 3.9, 0),
		Color = Color3.fromRGB(24, 26, 34),
		Material = Enum.Material.Metal,
		Parent = m,
	})
	for i = 1, 5 do
		part({
			Name = "BladeLight_" .. i,
			Size = Vector3.new(2.4, 0.3, 0.15),
			Position = Vector3.new(0, 1.2 + i * 1.1, 1.58),
			Color = glow,
			Material = Enum.Material.Neon,
			Parent = m,
		})
	end

	m.PrimaryPart = body
	return m
end

-- 18. NEW (School Map): Student Classroom Desk & Chair Set
local function createSchoolDeskModel(): Model
	local m = Instance.new("Model")
	m.Name = "SchoolDesk"

	local top = part({
		Name = "DeskTop",
		Size = Vector3.new(3.2, 0.25, 2.2),
		Position = Vector3.new(0, 2.6, 0),
		Color = Color3.fromRGB(195, 148, 95),
		Material = Enum.Material.Wood,
		Parent = m,
	})
	part({
		Name = "BookCubby",
		Size = Vector3.new(2.8, 0.5, 2.0),
		Position = Vector3.new(0, 2.2, 0),
		Color = Color3.fromRGB(70, 75, 85),
		Material = Enum.Material.Metal,
		Parent = m,
	})
	for _, sx in { -1.3, 1.3 } do
		for _, sz in { -0.8, 0.8 } do
			part({
				Name = "Leg",
				Size = Vector3.new(0.2, 2.0, 0.2),
				Position = Vector3.new(sx, 1.0, sz),
				Color = Color3.fromRGB(60, 65, 72),
				Material = Enum.Material.Metal,
				Parent = m,
			})
		end
	end

	m.PrimaryPart = top
	return m
end

-- 19. NEW (School Map): High School Hallway Locker Bank
local function createSchoolLockerModel(lockerColor: Color3?): Model
	local m = Instance.new("Model")
	m.Name = "SchoolLocker"
	local col = lockerColor or Color3.fromRGB(48, 118, 195)

	local body = part({
		Name = "LockerBank",
		Size = Vector3.new(4.2, 7.4, 2.0),
		Position = Vector3.new(0, 3.7, 0),
		Color = col,
		Material = Enum.Material.Metal,
		Parent = m,
	})
	for _, sx in { -1.3, 0, 1.3 } do
		part({
			Name = "DoorSeam",
			Size = Vector3.new(1.1, 6.8, 0.12),
			Position = Vector3.new(sx, 3.7, 1.0),
			Color = Color3.fromRGB(65, 138, 215),
			Material = Enum.Material.Metal,
			Parent = m,
		})
	end

	m.PrimaryPart = body
	return m
end

-- 20. (Camping Park Map): A-Frame Camping Tent with Ridge Pole & Entrance Detail
local function createCampingTentModel(tentColor: Color3?): Model
	local m = Instance.new("Model")
	m.Name = "CampingTent"
	local col = tentColor or Color3.fromRGB(225, 125, 45)

	local floorMat = part({
		Name = "TentGroundMat",
		Size = Vector3.new(5.6, 0.25, 6.4),
		Position = Vector3.new(0, 0.125, 0),
		Color = Color3.fromRGB(55, 62, 58),
		Material = Enum.Material.Fabric,
		Parent = m,
	})
	part({
		Name = "LeftSlope",
		Size = Vector3.new(0.3, 4.8, 6.2),
		CFrame = CFrame.new(-1.35, 2.1, 0) * CFrame.Angles(0, 0, math.rad(-32)),
		Color = col,
		Material = Enum.Material.Fabric,
		Parent = m,
	})
	part({
		Name = "RightSlope",
		Size = Vector3.new(0.3, 4.8, 6.2),
		CFrame = CFrame.new(1.35, 2.1, 0) * CFrame.Angles(0, 0, math.rad(32)),
		Color = col,
		Material = Enum.Material.Fabric,
		Parent = m,
	})
	part({
		Name = "BackPanel",
		Size = Vector3.new(4.2, 3.2, 0.2),
		Position = Vector3.new(0, 1.7, -3.0),
		Color = col:Lerp(Color3.new(0, 0, 0), 0.18),
		Material = Enum.Material.Fabric,
		Parent = m,
	})
	part({
		Name = "RidgePole",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(6.6, 0.24, 0.24),
		CFrame = CFrame.new(0, 4.15, 0) * CFrame.Angles(0, math.rad(90), 0),
		Color = Color3.fromRGB(190, 195, 200),
		Material = Enum.Material.Metal,
		Parent = m,
	})
	part({
		Name = "InteriorGlow",
		Size = Vector3.new(1.6, 1.8, 0.2),
		Position = Vector3.new(0, 1.2, 2.95),
		Color = Color3.fromRGB(255, 215, 130),
		Material = Enum.Material.Neon,
		Parent = m,
	})

	m.PrimaryPart = floorMat
	return m
end

-- 21. (Camping Park Map): Glowing Campfire, Stone Ring & Logs
local function createCampfireModel(): Model
	local m = Instance.new("Model")
	m.Name = "CampfirePit"

	local base = part({
		Name = "AshBase",
		Size = Vector3.new(3.2, 0.25, 3.2),
		Position = Vector3.new(0, 0.125, 0),
		Color = Color3.fromRGB(68, 64, 60),
		Material = Enum.Material.Slate,
		Parent = m,
	})
	for i = 0, 7 do
		local ang = math.rad(i * 45)
		part({
			Name = "RingStone_" .. i,
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.85, 0.65, 0.85),
			Position = Vector3.new(math.cos(ang) * 1.75, 0.32, math.sin(ang) * 1.75),
			Color = Color3.fromRGB(115, 112, 108),
			Material = Enum.Material.Rock,
			Parent = m,
		})
	end
	for _, angle in { 0, 60, 120 } do
		part({
			Name = "FireLog",
			Size = Vector3.new(2.8, 0.45, 0.55),
			CFrame = CFrame.new(0, 0.45, 0) * CFrame.Angles(0, math.rad(angle), 0),
			Color = Color3.fromRGB(108, 72, 42),
			Material = Enum.Material.Wood,
			Parent = m,
		})
	end
	local flame = part({
		Name = "FlameCore",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.5, 2.0, 1.5),
		Position = Vector3.new(0, 1.2, 0),
		Color = Color3.fromRGB(255, 125, 30),
		Material = Enum.Material.Neon,
		Parent = m,
	})
	part({
		Name = "FlameInner",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(0.95, 1.5, 0.95),
		Position = Vector3.new(0, 1.45, 0),
		Color = Color3.fromRGB(255, 220, 80),
		Material = Enum.Material.Neon,
		Parent = m,
	})
	attachLight(flame, Color3.fromRGB(255, 160, 70), 1.0, 26)

	m.PrimaryPart = base
	return m
end

-- 22. (Camping Park Map): Wooden Picnic Table & Benches
local function createPicnicTableModel(): Model
	local m = Instance.new("Model")
	m.Name = "PicnicTable"
	local wood = Color3.fromRGB(152, 105, 64)

	local top = part({
		Name = "TableTop",
		Size = Vector3.new(6.6, 0.35, 3.2),
		Position = Vector3.new(0, 2.8, 0),
		Color = wood,
		Material = Enum.Material.WoodPlanks,
		Parent = m,
	})
	for _, sz in { -2.4, 2.4 } do
		part({
			Name = "BenchSeat",
			Size = Vector3.new(6.6, 0.3, 1.1),
			Position = Vector3.new(0, 1.55, sz),
			Color = wood,
			Material = Enum.Material.WoodPlanks,
			Parent = m,
		})
	end
	for _, sx in { -2.4, 2.4 } do
		part({
			Name = "SupportFrame",
			Size = Vector3.new(0.4, 2.7, 5.2),
			Position = Vector3.new(sx, 1.35, 0),
			Color = Color3.fromRGB(118, 78, 45),
			Material = Enum.Material.Wood,
			Parent = m,
		})
	end

	m.PrimaryPart = top
	return m
end

-- 23. (Camping Park Map): Layered Pine Tree Prop
local function createPineTreeModel(): Model
	local m = Instance.new("Model")
	m.Name = "PineTree"

	local trunk = part({
		Name = "TreeTrunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(3.4, 1.45, 1.45),
		CFrame = CFrame.new(0, 1.7, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(98, 64, 38),
		Material = Enum.Material.Wood,
		Parent = m,
	})
	for idx, layer in {
		{ Y = 3.8, W = 5.6, H = 2.4, Col = Color3.fromRGB(38, 104, 52), Rot = 0 },
		{ Y = 5.6, W = 4.4, H = 2.3, Col = Color3.fromRGB(46, 122, 60), Rot = 45 },
		{ Y = 7.3, W = 3.1, H = 2.1, Col = Color3.fromRGB(56, 138, 68), Rot = 0 },
		{ Y = 8.8, W = 1.7, H = 1.7, Col = Color3.fromRGB(68, 152, 78), Rot = 45 },
	} do
		part({
			Name = "PineLayer_" .. idx,
			Size = Vector3.new(layer.W, layer.H, layer.W),
			CFrame = CFrame.new(0, layer.Y, 0) * CFrame.Angles(0, math.rad(layer.Rot), 0),
			Color = layer.Col,
			Material = Enum.Material.Grass,
			Parent = m,
		})
	end

	m.PrimaryPart = trunk
	return m
end

-- 24. NEW (Japanese Village Map): Blossoming Sakura Cherry Tree
local function createSakuraTreeModel(scale: number?): Model
	local s = scale or 1.0
	local m = Instance.new("Model")
	m.Name = "SakuraTree"

	local trunk = part({
		Name = "SakuraTrunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(4.6 * s, 1.4 * s, 1.4 * s),
		CFrame = CFrame.new(0, 2.3 * s, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(92, 62, 48),
		Material = Enum.Material.Wood,
		Parent = m,
	})
	for idx, cl in {
		{ Pos = Vector3.new(0, 6.2, 0), Size = Vector3.new(5.2, 3.6, 5.2), Col = Color3.fromRGB(255, 130, 178) },
		{ Pos = Vector3.new(2.0, 5.3, 1.2), Size = Vector3.new(3.6, 2.8, 3.6), Col = Color3.fromRGB(245, 108, 162) },
		{ Pos = Vector3.new(-2.1, 5.4, -1.0), Size = Vector3.new(3.8, 2.8, 3.8), Col = Color3.fromRGB(255, 148, 192) },
		{ Pos = Vector3.new(0.4, 5.5, -2.0), Size = Vector3.new(3.4, 2.6, 3.4), Col = Color3.fromRGB(248, 118, 170) },
	} do
		part({
			Name = "SakuraCanopy_" .. idx,
			Shape = Enum.PartType.Ball,
			Size = cl.Size * s,
			Position = cl.Pos * s,
			Color = cl.Col,
			Material = Enum.Material.SmoothPlastic,
			Parent = m,
		})
	end

	m.PrimaryPart = trunk
	return m
end

-- 25. NEW (Japanese Village Map): Traditional Stone Lantern (Toro)
local function createStoneLanternModel(): Model
	local m = Instance.new("Model")
	m.Name = "StoneLantern"
	local stone = Color3.fromRGB(145, 145, 142)

	local base = part({
		Name = "LanternBase",
		Size = Vector3.new(2.2, 0.6, 2.2),
		Position = Vector3.new(0, 0.3, 0),
		Color = stone,
		Material = Enum.Material.Cobblestone,
		Parent = m,
	})
	part({
		Name = "LanternPillar",
		Size = Vector3.new(1.0, 2.6, 1.0),
		Position = Vector3.new(0, 1.9, 0),
		Color = stone,
		Material = Enum.Material.Concrete,
		Parent = m,
	})
	part({
		Name = "LanternLedge",
		Size = Vector3.new(2.1, 0.4, 2.1),
		Position = Vector3.new(0, 3.4, 0),
		Color = stone,
		Material = Enum.Material.Cobblestone,
		Parent = m,
	})
	local glowCore = part({
		Name = "LanternLight",
		Size = Vector3.new(1.25, 1.15, 1.25),
		Position = Vector3.new(0, 4.15, 0),
		Color = Color3.fromRGB(255, 200, 110),
		Material = Enum.Material.Neon,
		Parent = m,
	})
	attachLight(glowCore, Color3.fromRGB(255, 188, 95), 0.75, 22)
	part({
		Name = "LanternRoof",
		Size = Vector3.new(2.8, 0.55, 2.8),
		Position = Vector3.new(0, 4.95, 0),
		Color = Color3.fromRGB(115, 118, 122),
		Material = Enum.Material.Slate,
		Parent = m,
	})
	part({
		Name = "LanternFinial",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(0.65, 0.65, 0.65),
		Position = Vector3.new(0, 5.45, 0),
		Color = stone,
		Material = Enum.Material.Concrete,
		Parent = m,
	})

	m.PrimaryPart = base
	return m
end

-- 26. NEW (Japanese Village Map): Wooden Ramen / Yatai Street Stall
local function createRamenStallModel(norenColor: Color3?): Model
	local m = Instance.new("Model")
	m.Name = "RamenStall"
	local wood = Color3.fromRGB(132, 86, 52)
	local cloth = norenColor or Color3.fromRGB(195, 42, 48)

	local counter = part({
		Name = "StallCounter",
		Size = Vector3.new(7.0, 3.1, 3.4),
		Position = Vector3.new(0, 1.55, 0),
		Color = wood,
		Material = Enum.Material.WoodPlanks,
		Parent = m,
	})
	part({
		Name = "CounterTop",
		Size = Vector3.new(7.4, 0.25, 4.0),
		Position = Vector3.new(0, 3.2, 0.2),
		Color = Color3.fromRGB(185, 138, 86),
		Material = Enum.Material.Wood,
		Parent = m,
	})
	for _, sx in { -3.2, 3.2 } do
		for _, sz in { -1.5, 1.5 } do
			part({
				Name = "StallPost",
				Size = Vector3.new(0.32, 4.2, 0.32),
				Position = Vector3.new(sx, 5.2, sz),
				Color = Color3.fromRGB(88, 56, 36),
				Material = Enum.Material.Wood,
				Parent = m,
			})
		end
	end
	part({
		Name = "StallRoof",
		Size = Vector3.new(8.2, 0.5, 4.6),
		CFrame = CFrame.new(0, 7.35, 0) * CFrame.Angles(math.rad(6), 0, 0),
		Color = Color3.fromRGB(52, 56, 68),
		Material = Enum.Material.Slate,
		Parent = m,
	})
	for i = -2, 2 do
		part({
			Name = "NorenCurtain_" .. i,
			Size = Vector3.new(1.15, 1.35, 0.12),
			Position = Vector3.new(i * 1.32, 6.25, 1.7),
			Color = cloth,
			Material = Enum.Material.Fabric,
			Parent = m,
		})
	end
	for _, sx in { -2.4, 2.4 } do
		part({
			Name = "MiniLantern",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.9, 1.1, 0.9),
			Position = Vector3.new(sx, 5.3, 1.85),
			Color = Color3.fromRGB(255, 85, 65),
			Material = Enum.Material.Neon,
			Parent = m,
		})
	end

	m.PrimaryPart = counter
	return m
end

-- 27. NEW (Japanese Village Map): Bamboo Planter Cluster
local function createBambooClusterModel(): Model
	local m = Instance.new("Model")
	m.Name = "BambooCluster"

	local planter = part({
		Name = "BambooPlanter",
		Size = Vector3.new(3.6, 1.2, 2.0),
		Position = Vector3.new(0, 0.6, 0),
		Color = Color3.fromRGB(98, 68, 44),
		Material = Enum.Material.WoodPlanks,
		Parent = m,
	})
	for idx, stalk in {
		{ X = -1.2, Z = -0.3, H = 7.4 },
		{ X = -0.4, Z = 0.35, H = 8.4 },
		{ X = 0.4, Z = -0.25, H = 6.9 },
		{ X = 1.2, Z = 0.2, H = 7.9 },
	} do
		part({
			Name = "BambooStalk_" .. idx,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(stalk.H, 0.42, 0.42),
			CFrame = CFrame.new(stalk.X, 1.0 + stalk.H * 0.5, stalk.Z) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(88, 162, 68),
			Material = Enum.Material.SmoothPlastic,
			Parent = m,
		})
		part({
			Name = "BambooLeaf_" .. idx,
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.7, 1.1, 1.7),
			Position = Vector3.new(stalk.X, 0.8 + stalk.H, stalk.Z),
			Color = Color3.fromRGB(72, 152, 62),
			Material = Enum.Material.Grass,
			Parent = m,
		})
	end

	m.PrimaryPart = planter
	return m
end

-- 28. NEW (Japanese Village Map): Low Tatami Tea Table (Chabudai)
local function createTeaTableModel(): Model
	local m = Instance.new("Model")
	m.Name = "JapaneseTeaTable"

	local top = part({
		Name = "TableTop",
		Size = Vector3.new(4.8, 0.28, 3.2),
		Position = Vector3.new(0, 1.35, 0),
		Color = Color3.fromRGB(115, 58, 36),
		Material = Enum.Material.Wood,
		Parent = m,
	})
	for _, sx in { -2.0, 2.0 } do
		for _, sz in { -1.2, 1.2 } do
			part({
				Name = "Leg",
				Size = Vector3.new(0.28, 1.2, 0.28),
				Position = Vector3.new(sx, 0.6, sz),
				Color = Color3.fromRGB(85, 42, 26),
				Material = Enum.Material.Wood,
				Parent = m,
			})
		end
	end
	for _, sz in { -2.4, 2.4 } do
		part({
			Name = "ZabutonCushion",
			Size = Vector3.new(1.7, 0.28, 1.7),
			Position = Vector3.new(0, 0.14, sz),
			Color = Color3.fromRGB(185, 48, 58),
			Material = Enum.Material.Fabric,
			Parent = m,
		})
	end
	part({
		Name = "Teapot",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(0.75, 0.62, 0.75),
		Position = Vector3.new(0, 1.75, 0),
		Color = Color3.fromRGB(45, 52, 58),
		Material = Enum.Material.Metal,
		Parent = m,
	})

	m.PrimaryPart = top
	return m
end

-- 29. NEW (Japanese Village Map): Festival Paper Lantern Post
local function createPaperLanternStandModel(lanternCol: Color3?): Model
	local m = Instance.new("Model")
	m.Name = "FestivalLantern"
	local col = lanternCol or Color3.fromRGB(255, 82, 68)

	local base = part({
		Name = "StandBase",
		Size = Vector3.new(1.6, 0.4, 1.6),
		Position = Vector3.new(0, 0.2, 0),
		Color = Color3.fromRGB(68, 44, 30),
		Material = Enum.Material.Wood,
		Parent = m,
	})
	part({
		Name = "Pole",
		Size = Vector3.new(0.32, 6.2, 0.32),
		Position = Vector3.new(0, 3.3, 0),
		Color = Color3.fromRGB(68, 44, 30),
		Material = Enum.Material.Wood,
		Parent = m,
	})
	part({
		Name = "CrossArm",
		Size = Vector3.new(1.6, 0.24, 0.24),
		Position = Vector3.new(0.6, 6.1, 0),
		Color = Color3.fromRGB(68, 44, 30),
		Material = Enum.Material.Wood,
		Parent = m,
	})
	local orb = part({
		Name = "PaperOrb",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.35, 1.7, 1.35),
		Position = Vector3.new(1.15, 5.15, 0),
		Color = col,
		Material = Enum.Material.Neon,
		Parent = m,
	})
	attachLight(orb, col, 0.7, 20)

	m.PrimaryPart = base
	return m
end

-- 30. NEW (Medieval Castle Map): Banded Oak & Gold Treasure Chest
local function createTreasureChestModel(): Model
	local m = Instance.new("Model")
	m.Name = "TreasureChest"

	local body = part({
		Name = "ChestBody",
		Size = Vector3.new(3.8, 1.9, 2.4),
		Position = Vector3.new(0, 0.95, 0),
		Color = Color3.fromRGB(112, 68, 36),
		Material = Enum.Material.WoodPlanks,
		Parent = m,
	})
	part({
		Name = "ChestLid",
		Size = Vector3.new(3.9, 0.85, 2.5),
		Position = Vector3.new(0, 2.3, 0),
		Color = Color3.fromRGB(128, 78, 42),
		Material = Enum.Material.WoodPlanks,
		Parent = m,
	})
	for _, sx in { -1.4, 1.4 } do
		part({
			Name = "GoldBand",
			Size = Vector3.new(0.32, 2.75, 2.62),
			Position = Vector3.new(sx, 1.38, 0),
			Color = Color3.fromRGB(225, 178, 58),
			Material = Enum.Material.Metal,
			Parent = m,
		})
	end
	part({
		Name = "GoldClasp",
		Size = Vector3.new(0.65, 0.75, 0.25),
		Position = Vector3.new(0, 1.9, 1.32),
		Color = Color3.fromRGB(245, 198, 65),
		Material = Enum.Material.Metal,
		Parent = m,
	})

	m.PrimaryPart = body
	return m
end

-- 31. NEW (Medieval Castle Map): Wrought-Iron Fire Brazier
local function createFireBrazierModel(): Model
	local m = Instance.new("Model")
	m.Name = "FireBrazier"

	local base = part({
		Name = "IronPedestal",
		Size = Vector3.new(2.2, 0.45, 2.2),
		Position = Vector3.new(0, 0.225, 0),
		Color = Color3.fromRGB(48, 50, 56),
		Material = Enum.Material.Metal,
		Parent = m,
	})
	part({
		Name = "IronStem",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2.6, 0.65, 0.65),
		CFrame = CFrame.new(0, 1.65, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(42, 44, 50),
		Material = Enum.Material.Metal,
		Parent = m,
	})
	part({
		Name = "FireBowl",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.95, 2.5, 2.5),
		CFrame = CFrame.new(0, 3.2, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(52, 54, 60),
		Material = Enum.Material.Metal,
		Parent = m,
	})
	local fire = part({
		Name = "BrazierFlame",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.8, 1.9, 1.8),
		Position = Vector3.new(0, 4.15, 0),
		Color = Color3.fromRGB(255, 132, 32),
		Material = Enum.Material.Neon,
		Parent = m,
	})
	attachLight(fire, Color3.fromRGB(255, 155, 60), 1.15, 30)

	m.PrimaryPart = base
	return m
end

-- 32. NEW (Medieval Castle Map): Knight Armor Stand
local function createArmorStandModel(): Model
	local m = Instance.new("Model")
	m.Name = "KnightArmor"

	local plinth = part({
		Name = "StonePlinth",
		Size = Vector3.new(2.8, 0.8, 2.8),
		Position = Vector3.new(0, 0.4, 0),
		Color = Color3.fromRGB(115, 112, 108),
		Material = Enum.Material.Cobblestone,
		Parent = m,
	})
	part({
		Name = "Greaves",
		Size = Vector3.new(1.4, 2.2, 0.9),
		Position = Vector3.new(0, 1.9, 0),
		Color = Color3.fromRGB(158, 165, 175),
		Material = Enum.Material.Metal,
		Parent = m,
	})
	part({
		Name = "Cuirass",
		Size = Vector3.new(2.0, 2.1, 1.2),
		Position = Vector3.new(0, 4.05, 0),
		Color = Color3.fromRGB(182, 188, 198),
		Material = Enum.Material.Metal,
		Parent = m,
	})
	part({
		Name = "Helmet",
		Size = Vector3.new(1.2, 1.3, 1.25),
		Position = Vector3.new(0, 5.75, 0),
		Color = Color3.fromRGB(175, 182, 192),
		Material = Enum.Material.Metal,
		Parent = m,
	})
	part({
		Name = "Plume",
		Size = Vector3.new(0.3, 0.85, 1.2),
		Position = Vector3.new(0, 6.65, -0.1),
		Color = Color3.fromRGB(195, 38, 46),
		Material = Enum.Material.Fabric,
		Parent = m,
	})
	part({
		Name = "Shield",
		Size = Vector3.new(1.5, 2.2, 0.22),
		Position = Vector3.new(1.25, 3.6, 0.45),
		Color = Color3.fromRGB(48, 86, 168),
		Material = Enum.Material.Metal,
		Parent = m,
	})

	m.PrimaryPart = plinth
	return m
end

-- 33. NEW (Medieval Castle Map): Wizard's Alchemy Desk
local function createAlchemyTableModel(): Model
	local m = Instance.new("Model")
	m.Name = "AlchemyTable"

	local top = part({
		Name = "DeskTop",
		Size = Vector3.new(6.2, 0.35, 3.2),
		Position = Vector3.new(0, 2.95, 0),
		Color = Color3.fromRGB(108, 68, 42),
		Material = Enum.Material.WoodPlanks,
		Parent = m,
	})
	for _, sx in { -2.7, 2.7 } do
		part({
			Name = "TimberLeg",
			Size = Vector3.new(0.45, 2.8, 2.8),
			Position = Vector3.new(sx, 1.4, 0),
			Color = Color3.fromRGB(82, 50, 30),
			Material = Enum.Material.Wood,
			Parent = m,
		})
	end
	local orb = part({
		Name = "CrystalOrb",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.1, 1.1, 1.1),
		Position = Vector3.new(0, 3.7, -0.2),
		Color = Color3.fromRGB(145, 85, 255),
		Material = Enum.Material.Neon,
		Parent = m,
	})
	attachLight(orb, Color3.fromRGB(155, 95, 255), 0.7, 18)
	for idx, flask in {
		{ X = -1.8, Col = Color3.fromRGB(55, 235, 130) },
		{ X = -1.1, Col = Color3.fromRGB(255, 70, 95) },
		{ X = 1.6, Col = Color3.fromRGB(65, 185, 255) },
	} do
		part({
			Name = "PotionFlask_" .. idx,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.85, 0.55, 0.55),
			CFrame = CFrame.new(flask.X, 3.55, 0.3) * CFrame.Angles(0, 0, math.rad(90)),
			Color = flask.Col,
			Material = Enum.Material.Neon,
			Parent = m,
		})
	end

	m.PrimaryPart = top
	return m
end

-- 34. NEW (Medieval Castle Map): Wooden Market Handcart
local function createWoodenCartModel(): Model
	local m = Instance.new("Model")
	m.Name = "WoodenCart"

	local bed = part({
		Name = "CartBed",
		Size = Vector3.new(6.2, 1.8, 3.6),
		Position = Vector3.new(0, 2.0, 0),
		Color = Color3.fromRGB(132, 86, 48),
		Material = Enum.Material.WoodPlanks,
		Parent = m,
	})
	for _, sz in { -1.95, 1.95 } do
		part({
			Name = "Wheel",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.32, 2.2, 2.2),
			CFrame = CFrame.new(0, 1.1, sz) * CFrame.Angles(0, math.rad(90), 0),
			Color = Color3.fromRGB(84, 54, 32),
			Material = Enum.Material.Wood,
			Parent = m,
		})
	end
	part({
		Name = "GoodsCrate",
		Size = Vector3.new(2.1, 1.6, 2.1),
		Position = Vector3.new(-1.1, 3.4, 0),
		Color = Color3.fromRGB(168, 122, 74),
		Material = Enum.Material.WoodPlanks,
		Parent = m,
	})
	part({
		Name = "GoodsSack",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.8, 1.5, 1.8),
		Position = Vector3.new(1.3, 3.3, 0),
		Color = Color3.fromRGB(195, 172, 132),
		Material = Enum.Material.Fabric,
		Parent = m,
	})

	m.PrimaryPart = bed
	return m
end

-- 35. NEW (Medieval Castle Map): Standing Royal Banner
local function createRoyalBannerStandModel(bannerColor: Color3?): Model
	local m = Instance.new("Model")
	m.Name = "RoyalBanner"
	local col = bannerColor or Color3.fromRGB(175, 36, 48)

	local base = part({
		Name = "BannerBase",
		Size = Vector3.new(1.8, 0.5, 1.8),
		Position = Vector3.new(0, 0.25, 0),
		Color = Color3.fromRGB(68, 70, 78),
		Material = Enum.Material.Metal,
		Parent = m,
	})
	part({
		Name = "Pole",
		Size = Vector3.new(0.28, 8.2, 0.28),
		Position = Vector3.new(0, 4.3, 0),
		Color = Color3.fromRGB(195, 158, 62),
		Material = Enum.Material.Metal,
		Parent = m,
	})
	part({
		Name = "Crossbar",
		Size = Vector3.new(2.8, 0.24, 0.24),
		Position = Vector3.new(0, 7.9, 0),
		Color = Color3.fromRGB(220, 178, 68),
		Material = Enum.Material.Metal,
		Parent = m,
	})
	part({
		Name = "ClothFlag",
		Size = Vector3.new(2.4, 5.2, 0.14),
		Position = Vector3.new(0, 5.2, 0.16),
		Color = col,
		Material = Enum.Material.Fabric,
		Parent = m,
	})
	part({
		Name = "GoldEmblem",
		Size = Vector3.new(0.85, 1.2, 0.18),
		Position = Vector3.new(0, 5.6, 0.18),
		Color = Color3.fromRGB(240, 198, 68),
		Material = Enum.Material.Metal,
		Parent = m,
	})

	m.PrimaryPart = base
	return m
end

--------------------------------------------------------------------------------
-- PERMANENT SKY LOUNGE OBSERVATION LOBBY BUILDER (V3 LUXURY ROOFTOP PAVILION)
--------------------------------------------------------------------------------
local LOBBY_VERSION = 5 -- Bump whenever lobby architecture/boards/vote pads change so saved places auto-upgrade!

local function ensureSkyLoungeLobby(mapFolder: Folder)
	local existingLobby = mapFolder:FindFirstChild("SkyLoungeLobby")
	if existingLobby then
		if existingLobby:GetAttribute("LobbyVersion") == LOBBY_VERSION then
			return
		end
		existingLobby:Destroy()
	end

	local lobbyY = WALL_HEIGHT + 2
	local lobbyFolder = Instance.new("Folder")
	lobbyFolder.Name = "SkyLoungeLobby"
	lobbyFolder:SetAttribute("LobbyVersion", LOBBY_VERSION)
	lobbyFolder.Parent = mapFolder

	local function placeLobbyDecor(model: Model, groundPos: Vector3, yawDeg: number)
		local bboxCF, bboxSize = model:GetBoundingBox()
		local bottomY = bboxCF.Position.Y - (bboxSize.Y * 0.5)
		local currentPivot = model:GetPivot()
		local pivotOffsetY = currentPivot.Position.Y - bottomY
		local deltaPos = Vector3.new(
			groundPos.X - currentPivot.Position.X,
			(groundPos.Y + pivotOffsetY) - currentPivot.Position.Y,
			groundPos.Z - currentPivot.Position.Z
		)
		model:PivotTo(
			CFrame.new(currentPivot.Position + deltaPos)
				* CFrame.Angles(0, math.rad(yawDeg), 0)
				* currentPivot.Rotation
		)
		model.Parent = lobbyFolder
	end

	-- 1. Main Architectural Dark-Slate Roof Terrace around the 48x48 Central Skylight (covers full 240x240 arena)
	for _, cp in {
		{ Size = Vector3.new(MAP_SIZE, 2, 96), Pos = Vector3.new(0, WALL_HEIGHT + 1, -72) },
		{ Size = Vector3.new(MAP_SIZE, 2, 96), Pos = Vector3.new(0, WALL_HEIGHT + 1, 72) },
		{ Size = Vector3.new(96, 2, 48), Pos = Vector3.new(-72, WALL_HEIGHT + 1, 0) },
		{ Size = Vector3.new(96, 2, 48), Pos = Vector3.new(72, WALL_HEIGHT + 1, 0) },
	} do
		part({
			Name = "CeilingSection",
			Size = cp.Size,
			Position = cp.Pos,
			Color = Color3.fromRGB(36, 40, 52),
			Material = Enum.Material.Slate,
			CastShadow = false,
			Parent = lobbyFolder,
		})
	end

	-- Outer Rooftop Parapet Rim along the 240x240 horizon so edges look finished
	for _, rim in {
		{ Size = Vector3.new(MAP_SIZE + 4, 3.5, 2.5), Pos = Vector3.new(0, lobbyY + 1.75, -120) },
		{ Size = Vector3.new(MAP_SIZE + 4, 3.5, 2.5), Pos = Vector3.new(0, lobbyY + 1.75, 120) },
		{ Size = Vector3.new(2.5, 3.5, MAP_SIZE), Pos = Vector3.new(-120, lobbyY + 1.75, 0) },
		{ Size = Vector3.new(2.5, 3.5, MAP_SIZE), Pos = Vector3.new(120, lobbyY + 1.75, 0) },
	} do
		part({
			Name = "OuterRoofParapet",
			Size = rim.Size,
			Position = rim.Pos,
			Color = Color3.fromRGB(48, 54, 68),
			Material = Enum.Material.Concrete,
			CastShadow = false,
			Parent = lobbyFolder,
		})
	end

	-- Landscaped Sky-Garden Planter Beds outside the Glass Railings (transforms empty roof into a scenic terrace!)
	for _, garden in {
		{ Size = Vector3.new(96, 1.4, 8), Pos = Vector3.new(0, lobbyY + 0.7, -53) },
		{ Size = Vector3.new(96, 1.4, 8), Pos = Vector3.new(0, lobbyY + 0.7, 53) },
		{ Size = Vector3.new(8, 1.4, 92), Pos = Vector3.new(-53, lobbyY + 0.7, 0) },
		{ Size = Vector3.new(8, 1.4, 92), Pos = Vector3.new(53, lobbyY + 0.7, 0) },
	} do
		part({
			Name = "SkyGardenPlanterBox",
			Size = garden.Size,
			Position = garden.Pos,
			Color = Color3.fromRGB(68, 74, 88),
			Material = Enum.Material.Cobblestone,
			CastShadow = false,
			Parent = lobbyFolder,
		})
		part({
			Name = "SkyGardenTurf",
			Size = garden.Size - Vector3.new(1.2, -0.15, 1.2),
			Position = garden.Pos + Vector3.new(0, 0.72, 0),
			Color = Color3.fromRGB(66, 138, 78),
			Material = Enum.Material.Grass,
			CastShadow = false,
			Parent = lobbyFolder,
		})
	end

	-- Ornamental Sakura & Pine Trees + Lanterns in the outer Sky-Garden Planters
	for _, treeSpot in {
		{ Pos = Vector3.new(-36, lobbyY + 1.4, -53), Sakura = true },
		{ Pos = Vector3.new(36, lobbyY + 1.4, -53), Sakura = true },
		{ Pos = Vector3.new(-53, lobbyY + 1.4, -26), Sakura = false },
		{ Pos = Vector3.new(-53, lobbyY + 1.4, 26), Sakura = true },
		{ Pos = Vector3.new(53, lobbyY + 1.4, -26), Sakura = true },
		{ Pos = Vector3.new(53, lobbyY + 1.4, 26), Sakura = false },
		{ Pos = Vector3.new(-30, lobbyY + 1.4, 53), Sakura = true },
		{ Pos = Vector3.new(30, lobbyY + 1.4, 53), Sakura = true },
	} do
		if treeSpot.Sakura then
			placeLobbyDecor(createSakuraTreeModel(0.82), treeSpot.Pos, math.random(0, 359))
		else
			placeLobbyDecor(createPineTreeModel(), treeSpot.Pos, math.random(0, 359))
		end
	end

	-- 2. Spacious 92x92 Luxury Multi-Tone Teak & Marble Promenade Deck
	for _, borderSlab in {
		{ Size = Vector3.new(94, 0.16, 23), Pos = Vector3.new(0, lobbyY + 0.08, -35.5) },
		{ Size = Vector3.new(94, 0.16, 23), Pos = Vector3.new(0, lobbyY + 0.08, 35.5) },
		{ Size = Vector3.new(23, 0.16, 48), Pos = Vector3.new(-35.5, lobbyY + 0.08, 0) },
		{ Size = Vector3.new(23, 0.16, 48), Pos = Vector3.new(35.5, lobbyY + 0.08, 0) },
	} do
		part({
			Name = "LobbyMarbleSubDeck",
			Size = borderSlab.Size,
			Position = borderSlab.Pos,
			Color = Color3.fromRGB(46, 52, 66),
			Material = Enum.Material.Marble,
			CastShadow = false,
			Parent = lobbyFolder,
		})
	end

	for _, deck in {
		{ Size = Vector3.new(88, 0.24, 19), Pos = Vector3.new(0, lobbyY + 0.12, -34.5) },
		{ Size = Vector3.new(88, 0.24, 19), Pos = Vector3.new(0, lobbyY + 0.12, 34.5) },
		{ Size = Vector3.new(19, 0.24, 50), Pos = Vector3.new(-34.5, lobbyY + 0.12, 0) },
		{ Size = Vector3.new(19, 0.24, 50), Pos = Vector3.new(34.5, lobbyY + 0.12, 0) },
	} do
		part({
			Name = "LobbyWoodDeck",
			Size = deck.Size,
			Position = deck.Pos,
			Color = Color3.fromRGB(152, 104, 68),
			Material = Enum.Material.WoodPlanks,
			CastShadow = false,
			Parent = lobbyFolder,
		})
	end

	-- 3. Central 48x48 Engineered Crystal Observation Skylight + Mullions + Illuminated Bevel Frame
	part({
		Name = "ObservationGlassFloor",
		Size = Vector3.new(48, 0.8, 48),
		Position = Vector3.new(0, WALL_HEIGHT + 1.5, 0),
		Color = Color3.fromRGB(162, 222, 255),
		Transparency = 0.68,
		Material = Enum.Material.Glass,
		CastShadow = false,
		CanQuery = false,
		Parent = lobbyFolder,
	})

	-- Sleek Dark-Titanium Structural Glass Mullions underneath the glass for depth & realism
	for _, mOffset in { -12, 12 } do
		part({
			Name = "SkylightMullionX",
			Size = Vector3.new(48, 0.35, 0.45),
			Position = Vector3.new(0, WALL_HEIGHT + 1.05, mOffset),
			Color = Color3.fromRGB(36, 42, 54),
			Material = Enum.Material.Metal,
			CastShadow = false,
			CanCollide = false,
			CanQuery = false,
			Parent = lobbyFolder,
		})
		part({
			Name = "SkylightMullionZ",
			Size = Vector3.new(0.45, 0.35, 48),
			Position = Vector3.new(mOffset, WALL_HEIGHT + 1.05, 0),
			Color = Color3.fromRGB(36, 42, 54),
			Material = Enum.Material.Metal,
			CastShadow = false,
			CanCollide = false,
			CanQuery = false,
			Parent = lobbyFolder,
		})
	end

	-- Double-Bevel Titanium & Glowing Cyan/Gold Skylight Curb
	for _, border in {
		{ Size = Vector3.new(50.4, 0.32, 1.3), Pos = Vector3.new(0, lobbyY + 0.16, -24.55) },
		{ Size = Vector3.new(50.4, 0.32, 1.3), Pos = Vector3.new(0, lobbyY + 0.16, 24.55) },
		{ Size = Vector3.new(1.3, 0.32, 47.8), Pos = Vector3.new(-24.55, lobbyY + 0.16, 0) },
		{ Size = Vector3.new(1.3, 0.32, 47.8), Pos = Vector3.new(24.55, lobbyY + 0.16, 0) },
	} do
		part({
			Name = "SkylightOuterCurb",
			Size = border.Size,
			Position = border.Pos,
			Color = Color3.fromRGB(34, 40, 54),
			Material = Enum.Material.Metal,
			Parent = lobbyFolder,
		})
	end

	for _, glowStrip in {
		{ Size = Vector3.new(48.6, 0.36, 0.28), Pos = Vector3.new(0, lobbyY + 0.18, -24.1) },
		{ Size = Vector3.new(48.6, 0.36, 0.28), Pos = Vector3.new(0, lobbyY + 0.18, 24.1) },
		{ Size = Vector3.new(0.28, 0.36, 48.0), Pos = Vector3.new(-24.1, lobbyY + 0.18, 0) },
		{ Size = Vector3.new(0.28, 0.36, 48.0), Pos = Vector3.new(24.1, lobbyY + 0.18, 0) },
	} do
		part({
			Name = "SkylightNeonFrame",
			Size = glowStrip.Size,
			Position = glowStrip.Pos,
			Color = Color3.fromRGB(75, 200, 255),
			Material = Enum.Material.Neon,
			Parent = lobbyFolder,
		})
	end

	-- 4 Corner Illuminated Skylight Bollards
	for _, cx in { -24.6, 24.6 } do
		for _, cz in { -24.6, 24.6 } do
			part({
				Name = "SkylightCornerBollard",
				Size = Vector3.new(1.5, 2.2, 1.5),
				Position = Vector3.new(cx, lobbyY + 1.1, cz),
				Color = Color3.fromRGB(38, 44, 58),
				Material = Enum.Material.Metal,
				Parent = lobbyFolder,
			})
			local capLight = part({
				Name = "SkylightBollardOrb",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(1.1, 1.1, 1.1),
				Position = Vector3.new(cx, lobbyY + 2.5, cz),
				Color = Color3.fromRGB(255, 215, 130),
				Material = Enum.Material.Neon,
				Parent = lobbyFolder,
			})
			attachLight(capLight, Color3.fromRGB(255, 215, 145), 0.55, 22)
		end
	end

	-- 4. Perimeter Tempered Glass Balustrade with Brushed Gold & Dark Metal Handrails
	for _, r in {
		{ Size = Vector3.new(92, 4.2, 0.5), Pos = Vector3.new(0, lobbyY + 2.2, -46.2) },
		{ Size = Vector3.new(92, 4.2, 0.5), Pos = Vector3.new(0, lobbyY + 2.2, 46.2) },
		{ Size = Vector3.new(0.5, 4.2, 92), Pos = Vector3.new(-46.2, lobbyY + 2.2, 0) },
		{ Size = Vector3.new(0.5, 4.2, 92), Pos = Vector3.new(46.2, lobbyY + 2.2, 0) },
	} do
		part({
			Name = "LobbyGlassRail",
			Size = r.Size,
			Position = r.Pos,
			Color = Color3.fromRGB(145, 205, 255),
			Transparency = 0.55,
			Material = Enum.Material.Glass,
			Parent = lobbyFolder,
		})
		part({
			Name = "LobbyRailTopBar",
			Size = Vector3.new(r.Size.X + 0.4, 0.35, r.Size.Z + 0.4),
			Position = r.Pos + Vector3.new(0, 2.2, 0),
			Color = Color3.fromRGB(38, 44, 58),
			Material = Enum.Material.Metal,
			Parent = lobbyFolder,
		})
		part({
			Name = "LobbyRailGoldTrim",
			Size = Vector3.new(r.Size.X + 0.45, 0.14, r.Size.Z + 0.45),
			Position = r.Pos + Vector3.new(0, 1.95, 0),
			Color = Color3.fromRGB(215, 172, 68),
			Material = Enum.Material.Metal,
			Parent = lobbyFolder,
		})
	end

	-- 5. Grand Pavilion Columns, Connected Crown Ring Beams, Louvered Pergola & Warm Hanging Chandeliers
	for _, px in { -45, 45 } do
		for _, pz in { -45, -15, 15, 45 } do
			part({
				Name = "LobbyPillarPedestal",
				Size = Vector3.new(3.4, 1.8, 3.4),
				Position = Vector3.new(px, lobbyY + 0.9, pz),
				Color = Color3.fromRGB(32, 36, 48),
				Material = Enum.Material.Marble,
				Parent = lobbyFolder,
			})
			part({
				Name = "LobbyPillar",
				Size = Vector3.new(2.3, 16.5, 2.3),
				Position = Vector3.new(px, lobbyY + 9.25, pz),
				Color = Color3.fromRGB(44, 50, 64),
				Material = Enum.Material.Metal,
				Parent = lobbyFolder,
			})
			for _, ringY in { lobbyY + 2.0, lobbyY + 16.2 } do
				part({
					Name = "LobbyPillarGoldBand",
					Size = Vector3.new(2.65, 0.35, 2.65),
					Position = Vector3.new(px, ringY, pz),
					Color = Color3.fromRGB(235, 190, 75),
					Material = Enum.Material.Neon,
					Parent = lobbyFolder,
				})
			end
		end
	end

	-- Longitudinal Tie Beams connecting the columns so rafters never float
	for _, bx in { -45, 45 } do
		part({
			Name = "PavilionSideBeam",
			Size = Vector3.new(2.6, 1.4, 94),
			Position = Vector3.new(bx, lobbyY + 17.6, 0),
			Color = Color3.fromRGB(38, 44, 58),
			Material = Enum.Material.Metal,
			Parent = lobbyFolder,
		})
	end
	for _, bz in { -45, 45 } do
		part({
			Name = "PavilionEndBeam",
			Size = Vector3.new(92.6, 1.4, 2.6),
			Position = Vector3.new(0, lobbyY + 17.6, bz),
			Color = Color3.fromRGB(38, 44, 58),
			Material = Enum.Material.Metal,
			Parent = lobbyFolder,
		})
	end

	-- Warm Cedar & Dark Titanium Pergola Louvers across the Pavilion
	for i = -5, 5 do
		local zPos = i * 8
		-- Keep directly above the central 48x48 skylight more open so daylight/moonlight streams in cleanly!
		if math.abs(zPos) >= 24 then
			part({
				Name = "PergolaBeam",
				Size = Vector3.new(92, 0.9, 1.3),
				Position = Vector3.new(0, lobbyY + 18.5, zPos),
				Color = Color3.fromRGB(138, 92, 58),
				Material = Enum.Material.Wood,
				Parent = lobbyFolder,
			})
		else
			for _, sideX in { -34.5, 34.5 } do
				part({
					Name = "PergolaSideLouver",
					Size = Vector3.new(23, 0.9, 1.3),
					Position = Vector3.new(sideX, lobbyY + 18.5, zPos),
					Color = Color3.fromRGB(138, 92, 58),
					Material = Enum.Material.Wood,
					Parent = lobbyFolder,
				})
			end
		end
	end

	-- Inner Skylight Aperture Frame Beams so side louvers terminate cleanly into a framed roof opening
	for _, innerX in { -23, 23 } do
		part({
			Name = "PergolaSkylightFrameX",
			Size = Vector3.new(1.2, 1.0, 48),
			Position = Vector3.new(innerX, lobbyY + 18.5, 0),
			Color = Color3.fromRGB(38, 44, 58),
			Material = Enum.Material.Metal,
			Parent = lobbyFolder,
		})
	end
	for _, innerZ in { -24, 24 } do
		part({
			Name = "PergolaSkylightFrameZ",
			Size = Vector3.new(47.2, 1.0, 1.2),
			Position = Vector3.new(0, lobbyY + 18.5, innerZ),
			Color = Color3.fromRGB(38, 44, 58),
			Material = Enum.Material.Metal,
			Parent = lobbyFolder,
		})
	end

	-- 6 Hanging Warm-Gold Halo Chandeliers around the Promenade
	for _, chandPos in {
		Vector3.new(-34, lobbyY + 14.5, -24),
		Vector3.new(34, lobbyY + 14.5, -24),
		Vector3.new(-34, lobbyY + 14.5, 24),
		Vector3.new(34, lobbyY + 14.5, 24),
		Vector3.new(0, lobbyY + 14.5, 34),
		Vector3.new(0, lobbyY + 14.5, -34),
	} do
		part({
			Name = "ChandelierRod",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(3.6, 0.2, 0.2),
			CFrame = CFrame.new(chandPos + Vector3.new(0, 2.0, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(45, 50, 62),
			Material = Enum.Material.Metal,
			Parent = lobbyFolder,
		})
		local halo = part({
			Name = "ChandelierHalo",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.35, 4.6, 4.6),
			CFrame = CFrame.new(chandPos) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(255, 215, 125),
			Material = Enum.Material.Neon,
			Parent = lobbyFolder,
		})
		part({
			Name = "ChandelierInnerCap",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.42, 3.5, 3.5),
			CFrame = CFrame.new(chandPos) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(36, 42, 54),
			Material = Enum.Material.Metal,
			Parent = lobbyFolder,
		})
		attachLight(halo, Color3.fromRGB(255, 222, 155), 0.75, 34)
	end

	-- 6. Royal VIP Arrival Carpet at South Promenade
	part({
		Name = "SpawnMarbleDais",
		Size = Vector3.new(18, 0.18, 17),
		Position = Vector3.new(0, lobbyY + 0.14, 34.5),
		Color = Color3.fromRGB(42, 48, 62),
		Material = Enum.Material.Marble,
		Parent = lobbyFolder,
	})
	part({
		Name = "SpawnGoldBorder",
		Size = Vector3.new(15.6, 0.22, 15.2),
		Position = Vector3.new(0, lobbyY + 0.18, 34.5),
		Color = Color3.fromRGB(220, 175, 62),
		Material = Enum.Material.Metal,
		Parent = lobbyFolder,
	})
	part({
		Name = "SpawnRedCarpet",
		Size = Vector3.new(14.6, 0.26, 14.2),
		Position = Vector3.new(0, lobbyY + 0.21, 34.5),
		Color = Color3.fromRGB(165, 34, 46),
		Material = Enum.Material.Fabric,
		Parent = lobbyFolder,
	})

	local existingSpawn = workspace:FindFirstChildOfClass("SpawnLocation")
	if existingSpawn then
		existingSpawn.Position = Vector3.new(0, lobbyY + 0.55, 35)
		existingSpawn.Size = Vector3.new(8, 0.6, 8)
		existingSpawn.Anchored = true
		existingSpawn.Neutral = true
		existingSpawn.Transparency = 1
		existingSpawn.CanCollide = true
		for _, ch in existingSpawn:GetChildren() do
			if ch:IsA("Decal") then
				ch.Transparency = 1
			end
		end
	end

	-- 7. Showpiece North Pavilion Backdrop & HD Rounded Display Boards
	part({
		Name = "LobbyFeatureWall",
		Size = Vector3.new(54, 14.5, 1.8),
		Position = Vector3.new(0, lobbyY + 7.25, -44.6),
		Color = Color3.fromRGB(22, 26, 38),
		Material = Enum.Material.Slate,
		Parent = lobbyFolder,
	})
	for _, wx in { -27.5, 27.5 } do
		part({
			Name = "FeatureWallPilaster",
			Size = Vector3.new(2.4, 15.5, 2.4),
			Position = Vector3.new(wx, lobbyY + 7.75, -44.4),
			Color = Color3.fromRGB(42, 48, 64),
			Material = Enum.Material.Metal,
			Parent = lobbyFolder,
		})
		part({
			Name = "FeatureWallGoldStrip",
			Size = Vector3.new(0.35, 13.5, 0.35),
			Position = Vector3.new(wx, lobbyY + 7.5, -43.1),
			Color = Color3.fromRGB(255, 205, 78),
			Material = Enum.Material.Neon,
			Parent = lobbyFolder,
		})
	end

	-- Crown Marquee Sign above Feature Wall
	createZoneSign(
		lobbyFolder,
		CFrame.new(0, lobbyY + 13.4, -43.4),
		Vector3.new(30, 2.5, 0.9),
		"★ PROP HUNT PLAZA • SKY LOUNGE ★",
		Color3.fromRGB(18, 22, 34),
		Color3.fromRGB(255, 210, 70),
		Color3.fromRGB(255, 232, 125)
	)

	local function createBoardGui(parentPart: BasePart, titleText: string, bodyText: string, accentColor: Color3)
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
			local sGui = Instance.new("SurfaceGui")
			sGui.Face = face
			sGui.LightInfluence = 0
			sGui.MaxDistance = 260
			sGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			sGui.PixelsPerStud = 42
			sGui.Parent = parentPart

			local bg = Instance.new("Frame")
			bg.Size = UDim2.new(1, -16, 1, -16)
			bg.Position = UDim2.fromOffset(8, 8)
			bg.BackgroundColor3 = Color3.fromRGB(16, 20, 32)
			bg.BorderSizePixel = 0
			bg.Parent = sGui

			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0, 22)
			c.Parent = bg

			local grad = Instance.new("UIGradient")
			grad.Color = ColorSequence.new(Color3.fromRGB(26, 34, 54), Color3.fromRGB(14, 18, 28))
			grad.Rotation = 115
			grad.Parent = bg

			local stroke = Instance.new("UIStroke")
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			stroke.Color = accentColor
			stroke.Thickness = 5
			stroke.Parent = bg

			local headerBox = Instance.new("Frame")
			headerBox.Size = UDim2.new(1, -36, 0.24, 0)
			headerBox.Position = UDim2.new(0, 18, 0.05, 0)
			headerBox.BackgroundColor3 = accentColor
			headerBox.BackgroundTransparency = 0.84
			headerBox.BorderSizePixel = 0
			headerBox.Parent = bg

			local hc = Instance.new("UICorner")
			hc.CornerRadius = UDim.new(0, 14)
			hc.Parent = headerBox

			local header = Instance.new("TextLabel")
			header.Size = UDim2.new(1, -24, 0.82, 0)
			header.Position = UDim2.new(0, 12, 0.09, 0)
			header.BackgroundTransparency = 1
			header.Font = Enum.Font.GothamBlack
			header.TextScaled = true
			header.TextColor3 = accentColor
			header.Text = titleText
			header.Parent = headerBox

			local body = Instance.new("TextLabel")
			body.Size = UDim2.new(1, -48, 0.62, 0)
			body.Position = UDim2.new(0, 24, 0.33, 0)
			body.BackgroundTransparency = 1
			body.Font = Enum.Font.GothamBold
			body.TextScaled = true
			body.TextXAlignment = Enum.TextXAlignment.Left
			body.TextYAlignment = Enum.TextYAlignment.Center
			body.TextColor3 = Color3.fromRGB(235, 242, 255)
			body.Text = bodyText
			body.Parent = bg
		end
	end

	local centerBoard = part({
		Name = "CenterWelcomeBoard",
		Size = Vector3.new(18, 8.6, 0.5),
		Position = Vector3.new(0, lobbyY + 6.9, -43.3),
		Color = Color3.fromRGB(16, 20, 32),
		Parent = lobbyFolder,
	})
	createBoardGui(
		centerBoard,
		"🎭 PROP HUNT : 6 MAPS!",
		"• 6 แมพใหญ่พิเศษ (240x240) โหวตเลือกก่อนเริ่มเกม!\n• เดินชมแมพจริงผ่านพื้นกระจกใสกลางล็อบบี้แบบสดๆ\n• ชนะรอบรับ +50 Coins • ผิวปากล่อรับ +5~20 Coins!",
		Color3.fromRGB(255, 215, 70)
	)

	local leftBoard = part({
		Name = "LeftHiderGuideBoard",
		Size = Vector3.new(14, 8.0, 0.5),
		Position = Vector3.new(-17.2, lobbyY + 6.7, -43.3),
		Color = Color3.fromRGB(16, 20, 32),
		Parent = lobbyFolder,
	})
	createBoardGui(
		leftBoard,
		"🟦 HIDER CONTROLS",
		"[Click / E] แปลงร่างเป็น Prop\n[F] ล็อกตัวนิ่ง  |  [R] หมุน 45°\n[V] ส่องดูเพื่อนร่วมทีม\n[T] ผิวปากรับเหรียญฟรี!\n[G] ร่างปลอม  |  [Shift] วิ่งหนี",
		Color3.fromRGB(75, 195, 255)
	)

	local rightBoard = part({
		Name = "RightSeekerGuideBoard",
		Size = Vector3.new(14, 8.0, 0.5),
		Position = Vector3.new(17.2, lobbyY + 6.7, -43.3),
		Color = Color3.fromRGB(16, 20, 32),
		Parent = lobbyFolder,
	})
	createBoardGui(
		rightBoard,
		"🟥 SEEKER CONTROLS",
		"[Click / Tap] ยิงปืนตรวจจับ\n• ยิงโดน Hider: ดาเมจ 50\n• ยิงโดนของจริง: เลือดลด -15!\n[Q] Sonar Radar สแกนระยะ\n[E] Speed Surge เร่งความเร็ว",
		Color3.fromRGB(255, 95, 105)
	)

	-- 8. East Champions Podium Stage (Stepped Marble Dais + Gold/Silver/Bronze Pedestals + Plaques)
	part({
		Name = "ChampionsDaisBase",
		Size = Vector3.new(10.5, 0.45, 17.5),
		Position = Vector3.new(36.5, lobbyY + 0.32, 0),
		Color = Color3.fromRGB(36, 42, 56),
		Material = Enum.Material.Marble,
		Parent = lobbyFolder,
	})
	createZoneSign(
		lobbyFolder,
		CFrame.new(41.5, lobbyY + 8.6, 0) * CFrame.Angles(0, math.rad(-90), 0),
		Vector3.new(14, 2.0, 0.6),
		"🏆 CHAMPIONS PODIUM",
		Color3.fromRGB(22, 26, 40),
		Color3.fromRGB(255, 210, 70)
	)

	for _, pod in {
		{ Rank = "1st", Label = "🥇 1ST", H = 3.8, Z = 0, Col = Color3.fromRGB(225, 178, 52) },
		{ Rank = "2nd", Label = "🥈 2ND", H = 2.8, Z = -4.6, Col = Color3.fromRGB(165, 178, 196) },
		{ Rank = "3rd", Label = "🥉 3RD", H = 2.0, Z = 4.6, Col = Color3.fromRGB(185, 115, 64) },
	} do
		local podPart = part({
			Name = "Podium_" .. pod.Rank,
			Size = Vector3.new(4.2, pod.H, 4.2),
			Position = Vector3.new(36.5, lobbyY + 0.5 + pod.H / 2, pod.Z),
			Color = pod.Col,
			Material = Enum.Material.Metal,
			Parent = lobbyFolder,
		})
		part({
			Name = "PodiumTopTrim_" .. pod.Rank,
			Size = Vector3.new(4.5, 0.25, 4.5),
			Position = Vector3.new(36.5, lobbyY + 0.5 + pod.H + 0.1, pod.Z),
			Color = Color3.fromRGB(245, 245, 250),
			Material = Enum.Material.Marble,
			Parent = lobbyFolder,
		})
		local pGui = Instance.new("SurfaceGui")
		pGui.Face = Enum.NormalId.Left
		pGui.LightInfluence = 0
		pGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		pGui.PixelsPerStud = 36
		pGui.Parent = podPart

		local pTxt = Instance.new("TextLabel")
		pTxt.Size = UDim2.new(1, -16, 0.65, 0)
		pTxt.Position = UDim2.new(0, 8, 0.175, 0)
		pTxt.BackgroundColor3 = Color3.fromRGB(18, 22, 34)
		pTxt.BackgroundTransparency = 0.15
		pTxt.Font = Enum.Font.GothamBlack
		pTxt.TextScaled = true
		pTxt.TextColor3 = Color3.fromRGB(255, 245, 215)
		pTxt.Text = pod.Label
		pTxt.Parent = pGui
		local pc = Instance.new("UICorner")
		pc.CornerRadius = UDim.new(0, 12)
		pc.Parent = pTxt
	end

	-- 9. 7 Physical 3D Illuminated Holographic Map Voting Pedestals along the North Promenade
	local votePadsFolder = Instance.new("Folder")
	votePadsFolder.Name = "MapVotePads"
	votePadsFolder.Parent = lobbyFolder

	for _, padInfo in {
		{ Id = "GrandPlaza", Tag = "MAP 01", Name = "ออฟฟิศพลาซ่า", X = -28.5, Col = Color3.fromRGB(65, 175, 255) },
		{ Id = "CyberpunkMall", Tag = "MAP 02", Name = "ห้างไซเบอร์พังก์", X = -19.0, Col = Color3.fromRGB(225, 70, 225) },
		{ Id = "SchoolCampus", Tag = "MAP 03", Name = "โรงเรียนมัธยม", X = -9.5, Col = Color3.fromRGB(255, 175, 55) },
		{ Id = "CampingPark", Tag = "MAP 04", Name = "แคมป์ปิ้งพาร์ค", X = 0.0, Col = Color3.fromRGB(75, 215, 115) },
		{ Id = "JapaneseVillage", Tag = "MAP 05", Name = "หมู่บ้านซากุระ", X = 9.5, Col = Color3.fromRGB(255, 120, 175) },
		{ Id = "MedievalCastle", Tag = "MAP 06", Name = "ปราสาทยุคกลาง", X = 19.0, Col = Color3.fromRGB(240, 85, 85) },
		{ Id = "Random", Tag = "RANDOM", Name = "สุ่มแมพปริศนา!", X = 28.5, Col = Color3.fromRGB(255, 210, 65) },
	} do
		-- Stepped Dark Metallic Frame + Neon Rim
		part({
			Name = "VotePadFrame_" .. padInfo.Id,
			Size = Vector3.new(7.6, 0.22, 6.0),
			Position = Vector3.new(padInfo.X, lobbyY + 0.2, -31.8),
			Color = Color3.fromRGB(26, 30, 44),
			Material = Enum.Material.Metal,
			Parent = lobbyFolder,
		})
		part({
			Name = "VotePadNeonRim_" .. padInfo.Id,
			Size = Vector3.new(7.25, 0.28, 5.65),
			Position = Vector3.new(padInfo.X, lobbyY + 0.24, -31.8),
			Color = padInfo.Col,
			Material = Enum.Material.Neon,
			CanCollide = false,
			CanQuery = false,
			Parent = lobbyFolder,
		})

		local votePad = part({
			Name = "VotePad_" .. padInfo.Id,
			Size = Vector3.new(6.9, 0.36, 5.3),
			Position = Vector3.new(padInfo.X, lobbyY + 0.3, -31.8),
			Color = Color3.fromRGB(20, 24, 36),
			Material = Enum.Material.SmoothPlastic,
			Parent = votePadsFolder,
		})
		votePad:SetAttribute("MapChoice", padInfo.Id)

		local topGui = Instance.new("SurfaceGui")
		topGui.Face = Enum.NormalId.Top
		topGui.LightInfluence = 0
		topGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		topGui.PixelsPerStud = 42
		topGui.Parent = votePad

		local padFrame = Instance.new("Frame")
		padFrame.Size = UDim2.new(1, -12, 1, -12)
		padFrame.Position = UDim2.fromOffset(6, 6)
		padFrame.BackgroundColor3 = Color3.fromRGB(18, 23, 36)
		padFrame.BorderSizePixel = 0
		padFrame.Parent = topGui

		local pc = Instance.new("UICorner")
		pc.CornerRadius = UDim.new(0, 18)
		pc.Parent = padFrame

		local padStroke = Instance.new("UIStroke")
		padStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		padStroke.Color = padInfo.Col
		padStroke.Thickness = 4
		padStroke.Parent = padFrame

		local tagLbl = Instance.new("TextLabel")
		tagLbl.Size = UDim2.new(1, -20, 0.28, 0)
		tagLbl.Position = UDim2.new(0, 10, 0.08, 0)
		tagLbl.BackgroundTransparency = 1
		tagLbl.Font = Enum.Font.GothamBlack
		tagLbl.TextScaled = true
		tagLbl.TextColor3 = padInfo.Col
		tagLbl.Text = padInfo.Tag
		tagLbl.Parent = padFrame

		local nameLbl = Instance.new("TextLabel")
		nameLbl.Size = UDim2.new(1, -16, 0.36, 0)
		nameLbl.Position = UDim2.new(0, 8, 0.36, 0)
		nameLbl.BackgroundTransparency = 1
		nameLbl.Font = Enum.Font.GothamBlack
		nameLbl.TextScaled = true
		nameLbl.TextColor3 = Color3.fromRGB(248, 250, 255)
		nameLbl.Text = padInfo.Name
		nameLbl.Parent = padFrame

		local subHint = Instance.new("TextLabel")
		subHint.Size = UDim2.new(1, -20, 0.2, 0)
		subHint.Position = UDim2.new(0, 10, 0.74, 0)
		subHint.BackgroundTransparency = 1
		subHint.Font = Enum.Font.GothamBold
		subHint.TextScaled = true
		subHint.TextColor3 = Color3.fromRGB(175, 195, 228)
		subHint.Text = "เหยียบเพื่อโหวต!"
		subHint.Parent = padFrame
	end

	-- 10. West VIP Sky Cafe, Arcade Corner & Rich Promenade Decor
	part({
		Name = "VipLoungeRug",
		Size = Vector3.new(13, 0.12, 26),
		Position = Vector3.new(-35, lobbyY + 0.25, 2),
		Color = Color3.fromRGB(42, 58, 92),
		Material = Enum.Material.Fabric,
		Parent = lobbyFolder,
	})
	createZoneSign(
		lobbyFolder,
		CFrame.new(-41.5, lobbyY + 8.6, -28) * CFrame.Angles(0, math.rad(90), 0),
		Vector3.new(14, 2.0, 0.6),
		"🕹️ ARCADE LOUNGE",
		Color3.fromRGB(22, 18, 38),
		Color3.fromRGB(195, 95, 255)
	)

	placeLobbyDecor(createSofaModel(Color3.fromRGB(178, 52, 66)), Vector3.new(-35.5, lobbyY + 0.24, -6), 90)
	placeLobbyDecor(createSofaModel(Color3.fromRGB(52, 112, 178)), Vector3.new(-35.5, lobbyY + 0.24, 10), 90)
	placeLobbyDecor(createCafeTableModel(), Vector3.new(-32.5, lobbyY + 0.24, -6), 0)
	placeLobbyDecor(createCafeTableModel(), Vector3.new(-32.5, lobbyY + 0.24, 10), 0)
	placeLobbyDecor(createFloorLampModel(Color3.fromRGB(255, 222, 145)), Vector3.new(-38.5, lobbyY + 0.24, 2), 0)

	-- Retro Arcade Corner (West-North)
	placeLobbyDecor(createArcadeCabinetModel(Color3.fromRGB(185, 65, 255)), Vector3.new(-41, lobbyY + 0.24, -32), 90)
	placeLobbyDecor(createArcadeCabinetModel(Color3.fromRGB(55, 205, 255)), Vector3.new(-41, lobbyY + 0.24, -27.5), 90)
	placeLobbyDecor(createArcadeCabinetModel(Color3.fromRGB(255, 95, 145)), Vector3.new(-41, lobbyY + 0.24, -23), 90)

	-- Refreshment Bar (East-North) & Trophy Accents
	placeLobbyDecor(createVendingMachineModel(Color3.fromRGB(215, 48, 58)), Vector3.new(41, lobbyY + 0.24, -31), -90)
	placeLobbyDecor(createVendingMachineModel(Color3.fromRGB(48, 132, 225)), Vector3.new(41, lobbyY + 0.24, -25.5), -90)
	placeLobbyDecor(createWaterCoolerModel(), Vector3.new(41, lobbyY + 0.24, -21), -90)
	placeLobbyDecor(createTreasureChestModel(), Vector3.new(36.5, lobbyY + 0.24, -11), -90)
	placeLobbyDecor(createRoyalBannerStandModel(Color3.fromRGB(185, 38, 48)), Vector3.new(39.5, lobbyY + 0.24, -10.5), -90)
	placeLobbyDecor(createRoyalBannerStandModel(Color3.fromRGB(42, 92, 185)), Vector3.new(39.5, lobbyY + 0.24, 10.5), -90)

	-- VIP Spawn Flanking Banners, Lanterns & Greenery
	placeLobbyDecor(createRoyalBannerStandModel(Color3.fromRGB(185, 38, 48)), Vector3.new(-9.5, lobbyY + 0.24, 41), 180)
	placeLobbyDecor(createRoyalBannerStandModel(Color3.fromRGB(185, 38, 48)), Vector3.new(9.5, lobbyY + 0.24, 41), 180)
	placeLobbyDecor(createPaperLanternStandModel(Color3.fromRGB(255, 185, 75)), Vector3.new(-20, lobbyY + 0.24, 39), 0)
	placeLobbyDecor(createPaperLanternStandModel(Color3.fromRGB(255, 185, 75)), Vector3.new(20, lobbyY + 0.24, 39), 0)

	for _, plantPos in {
		Vector3.new(-27, lobbyY + 0.24, 27),
		Vector3.new(27, lobbyY + 0.24, 27),
		Vector3.new(-27, lobbyY + 0.24, -25.5),
		Vector3.new(27, lobbyY + 0.24, -25.5),
	} do
		placeLobbyDecor(createPlantPotModel(), plantPos, 0)
	end
end

--------------------------------------------------------------------------------
-- ARENA SHELL BUILDER (ARCHITECTURAL OUTER WALLS, PILASTERS, WINDOWS & BEAMS)
--------------------------------------------------------------------------------
local function buildArenaShell(
	structureFolder: Folder,
	floorColor: Color3,
	floorMat: Enum.Material,
	wallColor: Color3,
	wainscotColor: Color3,
	windowGlowColor: Color3,
	wallMat: Enum.Material?,
	trimColor: Color3?,
	lightBrightness: number?
)
	local half = MAP_SIZE / 2
	local wMat = wallMat or Enum.Material.Concrete
	local tCol = trimColor or wainscotColor:Lerp(Color3.new(0, 0, 0), 0.25)
	local lBright = lightBrightness or 0.65

	part({
		Name = "MainFloor",
		Size = Vector3.new(MAP_SIZE, 2, MAP_SIZE),
		Position = Vector3.new(0, FLOOR_Y - 1, 0),
		Color = floorColor,
		Material = floorMat,
		Parent = structureFolder,
	})

	for _, w in {
		{ Name = "NorthWall", Size = Vector3.new(MAP_SIZE, WALL_HEIGHT, WALL_THICKNESS), Pos = Vector3.new(0, WALL_HEIGHT / 2, -half - 1) },
		{ Name = "SouthWall", Size = Vector3.new(MAP_SIZE, WALL_HEIGHT, WALL_THICKNESS), Pos = Vector3.new(0, WALL_HEIGHT / 2, half + 1) },
		{ Name = "EastWall", Size = Vector3.new(WALL_THICKNESS, WALL_HEIGHT, MAP_SIZE), Pos = Vector3.new(half + 1, WALL_HEIGHT / 2, 0) },
		{ Name = "WestWall", Size = Vector3.new(WALL_THICKNESS, WALL_HEIGHT, MAP_SIZE), Pos = Vector3.new(-half - 1, WALL_HEIGHT / 2, 0) },
	} do
		part({
			Name = w.Name,
			Size = w.Size,
			Position = w.Pos,
			Color = wallColor,
			Material = wMat,
			Parent = structureFolder,
		})
	end

	-- Lower Wainscot + Chair Rail Trim + Top Crown Cornice
	for _, side in {
		{ Axis = "X", Pos = Vector3.new(0, 0, -half + 0.25), Sign = 1 },
		{ Axis = "X", Pos = Vector3.new(0, 0, half - 0.25), Sign = -1 },
		{ Axis = "Z", Pos = Vector3.new(half - 0.25, 0, 0), Sign = -1 },
		{ Axis = "Z", Pos = Vector3.new(-half + 0.25, 0, 0), Sign = 1 },
	} do
		local isX = (side.Axis == "X")
		part({
			Name = "Wainscot",
			Size = if isX then Vector3.new(MAP_SIZE, 5.2, 0.5) else Vector3.new(0.5, 5.2, MAP_SIZE),
			Position = side.Pos + Vector3.new(0, 2.6, 0),
			Color = wainscotColor,
			Material = Enum.Material.Wood,
			Parent = structureFolder,
		})
		part({
			Name = "ChairRailTrim",
			Size = if isX then Vector3.new(MAP_SIZE, 0.45, 0.85) else Vector3.new(0.85, 0.45, MAP_SIZE),
			Position = side.Pos + Vector3.new(0, 5.35, 0),
			Color = tCol,
			Material = Enum.Material.SmoothPlastic,
			Parent = structureFolder,
		})
		part({
			Name = "CrownCornice",
			Size = if isX then Vector3.new(MAP_SIZE, 1.4, 1.3) else Vector3.new(1.3, 1.4, MAP_SIZE),
			Position = side.Pos + Vector3.new(0, WALL_HEIGHT - 0.7, 0),
			Color = tCol,
			Material = Enum.Material.SmoothPlastic,
			Parent = structureFolder,
		})
	end

	-- Architectural Wall Pilasters & Framed Mullioned Windows
	for i = -4, 4 do
		local offset = i * 24
		-- Pilaster columns between windows
		local pilOffset = offset + 12
		if math.abs(pilOffset) < half - 2 then
			for _, pPos in {
				Vector3.new(pilOffset, WALL_HEIGHT / 2, -half + 0.6),
				Vector3.new(pilOffset, WALL_HEIGHT / 2, half - 0.6),
				Vector3.new(half - 0.6, WALL_HEIGHT / 2, pilOffset),
				Vector3.new(-half + 0.6, WALL_HEIGHT / 2, pilOffset),
			} do
				part({
					Name = "WallPilaster",
					Size = Vector3.new(1.8, WALL_HEIGHT, 1.8),
					Position = pPos,
					Color = tCol,
					Material = wMat,
					Parent = structureFolder,
				})
			end
		end

		-- Framed Windows on all 4 sides
		for _, win in {
			{ Pos = Vector3.new(offset, 16, -half + 0.35), RotY = 0 },
			{ Pos = Vector3.new(offset, 16, half - 0.35), RotY = 180 },
			{ Pos = Vector3.new(half - 0.35, 16, offset), RotY = -90 },
			{ Pos = Vector3.new(-half + 0.35, 16, offset), RotY = 90 },
		} do
			local cf = CFrame.new(win.Pos) * CFrame.Angles(0, math.rad(win.RotY), 0)
			part({
				Name = "WindowFrameBack",
				Size = Vector3.new(14.2, 9.2, 0.35),
				CFrame = cf,
				Color = tCol,
				Material = Enum.Material.Metal,
				Parent = structureFolder,
			})
			part({
				Name = "WindowGlass",
				Size = Vector3.new(13.0, 8.0, 0.5),
				CFrame = cf * CFrame.new(0, 0, 0.12),
				Color = windowGlowColor,
				Transparency = 0.2,
				Material = Enum.Material.Glass,
				Parent = structureFolder,
			})
			-- Cross mullions
			part({
				Name = "WindowMullionV",
				Size = Vector3.new(0.32, 8.2, 0.62),
				CFrame = cf * CFrame.new(0, 0, 0.14),
				Color = tCol,
				Material = Enum.Material.Metal,
				Parent = structureFolder,
			})
			part({
				Name = "WindowMullionH",
				Size = Vector3.new(13.2, 0.32, 0.62),
				CFrame = cf * CFrame.new(0, 0, 0.14),
				Color = tCol,
				Material = Enum.Material.Metal,
				Parent = structureFolder,
			})
			-- Window Sill
			part({
				Name = "WindowSill",
				Size = Vector3.new(14.8, 0.45, 1.1),
				CFrame = cf * CFrame.new(0, -4.6, 0.25),
				Color = tCol,
				Material = Enum.Material.SmoothPlastic,
				Parent = structureFolder,
			})
		end
	end

	-- Overhead Ceiling Structural Beams (avoiding central 48x48 skylight)
	for _, bPos in { -88, -56, 56, 88 } do
		part({
			Name = "CeilingBeamX",
			Size = Vector3.new(MAP_SIZE, 1.4, 1.8),
			Position = Vector3.new(0, WALL_HEIGHT - 0.7, bPos),
			Color = tCol,
			Material = Enum.Material.Metal,
			CastShadow = false,
			Parent = structureFolder,
		})
		part({
			Name = "CeilingBeamZ",
			Size = Vector3.new(1.8, 1.4, MAP_SIZE),
			Position = Vector3.new(bPos, WALL_HEIGHT - 0.7, 0),
			Color = tCol,
			Material = Enum.Material.Metal,
			CastShadow = false,
			Parent = structureFolder,
		})
	end

	-- Framed Ceiling Light Fixtures
	for gx = -3, 3 do
		for gz = -3, 3 do
			if not (gx == 0 and gz == 0) then
				local lx, lz = gx * 32, gz * 32
				part({
					Name = "LightHousing",
					Size = Vector3.new(6.8, 0.5, 2.8),
					Position = Vector3.new(lx, WALL_HEIGHT - 0.25, lz),
					Color = Color3.fromRGB(36, 40, 48),
					Material = Enum.Material.Metal,
					CastShadow = false,
					Parent = structureFolder,
				})
				local bulb = part({
					Name = "CeilingLight",
					Size = Vector3.new(6.0, 0.25, 2.0),
					Position = Vector3.new(lx, WALL_HEIGHT - 0.55, lz),
					Color = windowGlowColor,
					Material = Enum.Material.Neon,
					CastShadow = false,
					Parent = structureFolder,
				})
				attachLight(bulb, windowGlowColor, lBright, 58)
			end
		end
	end
end

--------------------------------------------------------------------------------
-- MAP 1: GRAND PLAZA (240x240 — Dense Office Wing, Library, Arcade Lounge & Mega Warehouse)
--------------------------------------------------------------------------------
local function buildMapGrandPlaza(structureFolder: Folder): { { Build: () -> Model, Pos: Vector3, Yaw: number } }
	buildArenaShell(
		structureFolder,
		Color3.fromRGB(92, 96, 108),
		Enum.Material.Concrete,
		Color3.fromRGB(224, 218, 206),
		Color3.fromRGB(118, 84, 56),
		Color3.fromRGB(255, 246, 228),
		Enum.Material.SmoothPlastic,
		Color3.fromRGB(78, 56, 38),
		0.68
	)

	-- Rich Zoned Flooring with Decorative Borders
	part({ Name = "OfficeWoodFloor", Size = Vector3.new(102, 0.1, 102), Position = Vector3.new(60, 0.05, -60), Color = Color3.fromRGB(158, 114, 76), Material = Enum.Material.WoodPlanks, Parent = structureFolder })
	part({ Name = "OfficeAreaRugBorder", Size = Vector3.new(71, 0.12, 61), Position = Vector3.new(66, 0.06, -64), Color = Color3.fromRGB(198, 165, 92), Material = Enum.Material.Fabric, Parent = structureFolder })
	part({ Name = "OfficeAreaRug", Size = Vector3.new(68, 0.14, 58), Position = Vector3.new(66, 0.07, -64), Color = Color3.fromRGB(42, 74, 118), Material = Enum.Material.Fabric, Parent = structureFolder })

	part({ Name = "ArcadeFloorBorder", Size = Vector3.new(104, 0.09, 104), Position = Vector3.new(-60, 0.045, 60), Color = Color3.fromRGB(140, 52, 210), Material = Enum.Material.SmoothPlastic, Parent = structureFolder })
	part({ Name = "ArcadeFloor", Size = Vector3.new(100, 0.11, 100), Position = Vector3.new(-60, 0.055, 60), Color = Color3.fromRGB(36, 42, 64), Material = Enum.Material.Fabric, Parent = structureFolder })

	-- Warehouse & Logistics Safety Floor Borders
	for _, wh in { { X = -62, Z = -62 }, { X = 62, Z = 62 } } do
		part({ Name = "WarehouseHazardBorder", Size = Vector3.new(98, 0.09, 98), Position = Vector3.new(wh.X, 0.045, wh.Z), Color = Color3.fromRGB(228, 175, 42), Material = Enum.Material.Concrete, Parent = structureFolder })
		part({ Name = "WarehousePad", Size = Vector3.new(94, 0.11, 94), Position = Vector3.new(wh.X, 0.055, wh.Z), Color = Color3.fromRGB(80, 84, 92), Material = Enum.Material.Concrete, Parent = structureFolder })
	end

	-- Central Marble Courtyard + Gold Trim + Tiered Fountain Centerpiece
	part({ Name = "CenterCourtyardGoldTrim", Size = Vector3.new(58, 0.1, 58), Position = Vector3.new(0, 0.05, 0), Color = Color3.fromRGB(195, 162, 72), Material = Enum.Material.Marble, Parent = structureFolder })
	part({ Name = "CenterCourtyardPad", Size = Vector3.new(55, 0.13, 55), Position = Vector3.new(0, 0.065, 0), Color = Color3.fromRGB(212, 206, 198), Material = Enum.Material.Marble, Parent = structureFolder })

	-- Plaza Centerpiece Marble Fountain
	part({ Name = "FountainOuterRim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.8, 14, 14), CFrame = CFrame.new(0, 0.9, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(228, 224, 218), Material = Enum.Material.Marble, Parent = structureFolder })
	part({ Name = "FountainWater", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.5, 12.2, 12.2), CFrame = CFrame.new(0, 1.15, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(68, 185, 245), Transparency = 0.25, Material = Enum.Material.Glass, Parent = structureFolder })
	part({ Name = "FountainPillar", Shape = Enum.PartType.Cylinder, Size = Vector3.new(5.8, 2.6, 2.6), CFrame = CFrame.new(0, 3.2, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(218, 214, 208), Material = Enum.Material.Marble, Parent = structureFolder })
	part({ Name = "FountainUpperBowl", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.0, 6.4, 6.4), CFrame = CFrame.new(0, 5.8, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(228, 224, 218), Material = Enum.Material.Marble, Parent = structureFolder })
	local fountainOrb = part({ Name = "FountainGlowRing", Shape = Enum.PartType.Ball, Size = Vector3.new(2.2, 2.2, 2.2), Position = Vector3.new(0, 7.2, 0), Color = Color3.fromRGB(115, 220, 255), Material = Enum.Material.Neon, Parent = structureFolder })
	attachLight(fountainOrb, Color3.fromRGB(125, 215, 255), 0.9, 36)

	-- Framed Partition Walls with Wood Baseboards, Top Trim & Tinted Glass Clerestory Windows
	for i, iw in {
		{ Size = Vector3.new(62, 18, 1.8), Pos = Vector3.new(68, 9, -10) },
		{ Size = Vector3.new(1.8, 18, 62), Pos = Vector3.new(10, 9, -68) },
		{ Size = Vector3.new(62, 18, 1.8), Pos = Vector3.new(-68, 9, 10) },
		{ Size = Vector3.new(1.8, 18, 62), Pos = Vector3.new(-10, 9, 68) },
		{ Size = Vector3.new(42, 18, 1.8), Pos = Vector3.new(-64, 9, -42) },
		{ Size = Vector3.new(1.8, 18, 42), Pos = Vector3.new(42, 9, 64) },
	} do
		local isX = iw.Size.X > iw.Size.Z
		local wallLen = math.max(iw.Size.X, iw.Size.Z)
		-- Lower textured wall (0..9.2) + Upper header lintel (14.4..18) + Tinted Glass Transom Window between them!
		part({
			Name = "PartitionLower_" .. i,
			Size = if isX then Vector3.new(wallLen, 9.2, 1.8) else Vector3.new(1.8, 9.2, wallLen),
			Position = Vector3.new(iw.Pos.X, 4.6, iw.Pos.Z),
			Color = Color3.fromRGB(194, 188, 178),
			Material = Enum.Material.Concrete,
			Parent = structureFolder,
		})
		part({
			Name = "PartitionUpper_" .. i,
			Size = if isX then Vector3.new(wallLen, 3.8, 1.8) else Vector3.new(1.8, 3.8, wallLen),
			Position = Vector3.new(iw.Pos.X, 16.1, iw.Pos.Z),
			Color = Color3.fromRGB(194, 188, 178),
			Material = Enum.Material.Concrete,
			Parent = structureFolder,
		})
		part({
			Name = "PartitionTransomGlass_" .. i,
			Size = if isX then Vector3.new(wallLen - 3, 5.0, 0.45) else Vector3.new(0.45, 5.0, wallLen - 3),
			Position = Vector3.new(iw.Pos.X, 11.7, iw.Pos.Z),
			Color = Color3.fromRGB(135, 188, 222),
			Transparency = 0.48,
			Material = Enum.Material.Glass,
			Parent = structureFolder,
		})
		for m = -math.floor(wallLen * 0.35), math.floor(wallLen * 0.35), 14 do
			part({
				Name = "PartitionMullion_" .. i,
				Size = Vector3.new(1.9, 5.2, 1.9),
				Position = if isX then Vector3.new(iw.Pos.X + m, 11.7, iw.Pos.Z) else Vector3.new(iw.Pos.X, 11.7, iw.Pos.Z + m),
				Color = Color3.fromRGB(62, 52, 44),
				Material = Enum.Material.Metal,
				Parent = structureFolder,
			})
		end
		part({ Name = "PartitionBase_" .. i, Size = Vector3.new(iw.Size.X + 0.3, 2.2, iw.Size.Z + 0.3), Position = Vector3.new(iw.Pos.X, 1.1, iw.Pos.Z), Color = Color3.fromRGB(112, 78, 50), Material = Enum.Material.Wood, Parent = structureFolder })
		part({ Name = "PartitionSill_" .. i, Size = Vector3.new(iw.Size.X + 0.25, 0.45, iw.Size.Z + 0.25), Position = Vector3.new(iw.Pos.X, 9.2, iw.Pos.Z), Color = Color3.fromRGB(78, 56, 38), Material = Enum.Material.Wood, Parent = structureFolder })
		part({ Name = "PartitionCap_" .. i, Size = Vector3.new(iw.Size.X + 0.4, 0.7, iw.Size.Z + 0.4), Position = Vector3.new(iw.Pos.X, 18.2, iw.Pos.Z), Color = Color3.fromRGB(78, 56, 38), Material = Enum.Material.Wood, Parent = structureFolder })
	end

	-- Zone Signboards
	createZoneSign(structureFolder, CFrame.new(68, 15.2, -10), Vector3.new(18, 3.2, 2.2), "OFFICE & LIBRARY", Color3.fromRGB(28, 38, 56), Color3.fromRGB(95, 195, 255))
	createZoneSign(structureFolder, CFrame.new(-68, 15.2, 10), Vector3.new(18, 3.2, 2.2), "ARCADE & CAFE", Color3.fromRGB(38, 24, 58), Color3.fromRGB(220, 95, 255))
	createZoneSign(structureFolder, CFrame.new(-64, 15.2, -42), Vector3.new(16, 3.2, 2.2), "WAREHOUSE", Color3.fromRGB(45, 42, 34), Color3.fromRGB(255, 195, 65))
	createZoneSign(structureFolder, CFrame.new(42, 15.2, 64) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(16, 3.2, 2.2), "LOGISTICS BAY", Color3.fromRGB(45, 42, 34), Color3.fromRGB(255, 195, 65))

	local blueBarrel = function() return createBarrelModel(Color3.fromRGB(48, 108, 175), Color3.fromRGB(235, 235, 240)) end
	local redBarrel = function() return createBarrelModel(Color3.fromRGB(195, 55, 50), Color3.fromRGB(245, 195, 45)) end
	local greenBarrel = function() return createBarrelModel(Color3.fromRGB(55, 145, 80), Color3.fromRGB(240, 240, 240)) end

	local props: { { Build: () -> Model, Pos: Vector3, Yaw: number } } = {}
	local function add(buildFn: () -> Model, x: number, z: number, yaw: number?)
		table.insert(props, { Build = buildFn, Pos = Vector3.new(x, 0, z), Yaw = yaw or 0 })
	end

	-- 1. NE Office & Library Wing (~55 props)
	for x = 22, 106, 12 do
		add(createBookshelfModel, x, -114, 0)
	end
	for z = -102, -30, 12 do
		add(createBookshelfModel, 114, z, -90)
	end
	local chairColors = {
		Color3.fromRGB(45, 115, 195),
		Color3.fromRGB(50, 55, 65),
		Color3.fromRGB(185, 60, 65),
		Color3.fromRGB(55, 145, 95),
	}
	local cIdx = 0
	for _, x in { 32, 54, 76, 96 } do
		for _, z in { -92, -68, -44 } do
			cIdx += 1
			local col = chairColors[(cIdx % #chairColors) + 1]
			add(createComputerDeskModel, x, z, 0)
			add(function() return createOfficeChairModel(col) end, x, z + 4, 180)
			if cIdx % 2 == 0 then
				add(createTrashBinModel, x + 5, z, 0)
			else
				add(createFilingCabinetModel, x - 5, z, 0)
			end
		end
	end
	for _, z in { -98, -86, -74, -52, -40 } do
		add(createFilingCabinetModel, 15, z, 90)
	end
	add(createWaterCoolerModel, 15, -62, 90)
	add(createWaterCoolerModel, 15, -24, 90)
	add(createPlantPotModel, 18, -112, 0)
	add(createPlantPotModel, 112, -112, 45)
	add(createPlantPotModel, 112, -20, 0)
	add(createFloorLampModel, 44, -22, 0)
	add(createFloorLampModel, 88, -22, 0)

	-- 2. SW Arcade & Cafe Lounge Wing (~52 props)
	local arcadeColors = {
		Color3.fromRGB(165, 55, 245),
		Color3.fromRGB(245, 70, 120),
		Color3.fromRGB(55, 185, 250),
		Color3.fromRGB(80, 225, 110),
		Color3.fromRGB(255, 195, 50),
	}
	for i, z in { 24, 34, 44, 54, 64, 74, 84, 94, 104 } do
		local ac = arcadeColors[(i % #arcadeColors) + 1]
		add(function() return createArcadeCabinetModel(ac) end, -114, z, 90)
	end
	for i, x in { -102, -92, -82, -72, -58, -48, -38, -28 } do
		if i <= 4 then
			local vc = if i % 2 == 0 then Color3.fromRGB(210, 45, 55) else Color3.fromRGB(45, 125, 215)
			add(function() return createVendingMachineModel(vc) end, x, 114, 180)
		else
			local ac = arcadeColors[(i % #arcadeColors) + 1]
			add(function() return createArcadeCabinetModel(ac) end, x, 114, 180)
		end
	end
	for _, cx in { -86, -58, -32 } do
		for _, cz in { 42, 78 } do
			add(createCafeTableModel, cx, cz, 0)
			add(function() return createSofaModel(Color3.fromRGB(175, 58, 68)) end, cx, cz - 7, 0)
			add(function() return createSofaModel(Color3.fromRGB(58, 115, 168)) end, cx, cz + 7, 180)
			add(createFloorLampModel, cx - 8, cz, 0)
		end
	end
	add(createTrashBinModel, -64, 113, 0)
	add(createTrashBinModel, -16, 48, 0)
	add(createWaterCoolerModel, -16, 88, -90)
	add(createPlantPotModel, -112, 112, 0)
	add(createPlantPotModel, -18, 112, 0)
	add(createPlantPotModel, -112, 18, 0)

	-- 3. NW Mega Warehouse Sector (~45 props)
	for _, pos in {
		{ -108, -108 }, { -100, -108 }, { -92, -108 }, { -108, -98 }, { -98, -98 },
		{ -76, -108 }, { -68, -108 }, { -52, -108 }, { -44, -108 },
		{ -108, -72 }, { -100, -72 }, { -108, -62 },
		{ -48, -72 }, { -40, -72 }, { -78, -24 }, { -68, -24 },
	} do
		add(function() return createCrateModel(if (pos[1] + pos[2]) % 3 == 0 then 0.85 else 1.0) end, pos[1], pos[2], (pos[1] * 7) % 45)
	end
	for _, pPos in {
		{ -84, -88 }, { -62, -88 }, { -38, -88 },
		{ -88, -58 }, { -64, -58 }, { -34, -58 },
		{ -96, -28 }, { -52, -26 }, { -28, -28 },
	} do
		add(createPalletStackModel, pPos[1], pPos[2], (pPos[1] * 5) % 30)
	end
	for idx, bPos in {
		{ -108, -84 }, { -104, -82 }, { -108, -50 }, { -102, -48 },
		{ -78, -102 }, { -74, -98 }, { -54, -96 }, { -30, -104 }, { -26, -100 },
		{ -86, -32 }, { -42, -30 }, { -24, -44 },
	} do
		local bFn = if idx % 3 == 0 then redBarrel elseif idx % 3 == 1 then blueBarrel else greenBarrel
		add(bFn, bPos[1], bPos[2], 0)
	end
	for _, cPos in { { -56, -16 }, { -36, -16 }, { -20, -32 }, { -92, -16 }, { -110, -38 } } do
		add(createTrafficConeModel, cPos[1], cPos[2], 0)
	end

	-- 4. SE Logistics & Shipping Bay (~42 props)
	for _, pos in {
		{ 108, 108 }, { 100, 108 }, { 92, 108 }, { 108, 98 }, { 98, 98 },
		{ 76, 108 }, { 68, 108 }, { 108, 76 }, { 108, 68 },
		{ 62, 82 }, { 70, 82 }, { 26, 98 }, { 26, 90 }, { 84, 34 },
	} do
		add(function() return createCrateModel(1.0) end, pos[1], pos[2], (pos[2] * 7) % 35)
	end
	for _, pPos in {
		{ 84, 88 }, { 58, 98 }, { 88, 56 }, { 62, 54 },
		{ 98, 36 }, { 64, 28 }, { 26, 68 }, { 26, 44 },
	} do
		add(createPalletStackModel, pPos[1], pPos[2], (pPos[2] * 5) % 25)
	end
	for idx, bPos in {
		{ 108, 86 }, { 104, 82 }, { 82, 104 }, { 54, 108 }, { 50, 104 },
		{ 104, 48 }, { 98, 46 }, { 74, 42 }, { 52, 36 }, { 24, 80 }, { 28, 54 },
	} do
		local bFn = if idx % 3 == 0 then redBarrel elseif idx % 3 == 1 then blueBarrel else greenBarrel
		add(bFn, bPos[1], bPos[2], 0)
	end
	for _, cPos in { { 24, 24 }, { 38, 20 }, { 54, 18 }, { 82, 18 }, { 18, 38 } } do
		add(createTrafficConeModel, cPos[1], cPos[2], 0)
	end
	add(createTrashBinModel, 34, 96, 0)
	add(createTrashBinModel, 96, 22, 0)
	add(createVendingMachineModel, 16, 108, 180)

	-- 5. Central Atrium Courtyard & Crosswalk Corridors (~20 props)
	for _, p in { { -18, -18 }, { 18, -18 }, { -18, 18 }, { 18, 18 }, { -38, -6 }, { 38, 6 }, { -6, -38 }, { 6, 38 } } do
		add(createPlantPotModel, p[1], p[2], 0)
	end
	add(function() return createSofaModel(Color3.fromRGB(70, 78, 92)) end, 0, -16, 0)
	add(function() return createSofaModel(Color3.fromRGB(70, 78, 92)) end, 0, 16, 180)
	add(function() return createSofaModel(Color3.fromRGB(70, 78, 92)) end, -16, 0, 90)
	add(function() return createSofaModel(Color3.fromRGB(70, 78, 92)) end, 16, 0, -90)
	add(createCafeTableModel, -12, -12, 0)
	add(createCafeTableModel, 12, 12, 0)
	add(createTrashBinModel, -20, 8, 0)
	add(createTrashBinModel, 20, -8, 0)
	add(createFloorLampModel, -18, -10, 0)
	add(createFloorLampModel, 18, 10, 0)

	return props
end

--------------------------------------------------------------------------------
-- MAP 2: CYBERPUNK NEON MALL (240x240 — Dense Night Mall, Server Core & Cyber Lounge)
--------------------------------------------------------------------------------
local function buildMapCyberpunkMall(structureFolder: Folder): { { Build: () -> Model, Pos: Vector3, Yaw: number } }
	buildArenaShell(
		structureFolder,
		Color3.fromRGB(22, 26, 38),
		Enum.Material.SmoothPlastic,
		Color3.fromRGB(30, 34, 50),
		Color3.fromRGB(155, 32, 195),
		Color3.fromRGB(0, 215, 245),
		Enum.Material.Metal,
		Color3.fromRGB(18, 22, 34),
		0.58
	)

	-- Glowing Neon Floor Grid Strips across 240x240
	for i = -3, 3 do
		part({
			Name = "CyberGridLineX_" .. i,
			Size = Vector3.new(MAP_SIZE - 8, 0.1, 0.5),
			Position = Vector3.new(0, 0.05, i * 32),
			Color = Color3.fromRGB(0, 195, 235),
			Material = Enum.Material.Neon,
			Parent = structureFolder,
		})
		part({
			Name = "CyberGridLineZ_" .. i,
			Size = Vector3.new(0.5, 0.1, MAP_SIZE - 8),
			Position = Vector3.new(i * 32, 0.05, 0),
			Color = Color3.fromRGB(215, 45, 175),
			Material = Enum.Material.Neon,
			Parent = structureFolder,
		})
	end

	-- Central Hologram Core Monument in Cyber Plaza
	part({ Name = "HoloBaseOuter", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 15, 15), CFrame = CFrame.new(0, 0.3, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(28, 32, 46), Material = Enum.Material.Metal, Parent = structureFolder })
	part({ Name = "HoloBaseRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.7, 12.6, 12.6), CFrame = CFrame.new(0, 0.36, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(0, 225, 255), Material = Enum.Material.Neon, Parent = structureFolder })
	part({ Name = "HoloBaseInner", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.85, 11.4, 11.4), CFrame = CFrame.new(0, 0.42, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(22, 26, 38), Material = Enum.Material.Metal, Parent = structureFolder })
	local holoCore = part({ Name = "HoloCrystalCore", Size = Vector3.new(3.2, 7.2, 3.2), CFrame = CFrame.new(0, 6.2, 0) * CFrame.Angles(math.rad(15), math.rad(45), math.rad(15)), Color = Color3.fromRGB(0, 235, 255), Transparency = 0.25, Material = Enum.Material.Neon, Parent = structureFolder })
	attachLight(holoCore, Color3.fromRGB(0, 215, 255), 1.35, 48)
	part({ Name = "HoloOrbitRingA", Size = Vector3.new(8.2, 0.35, 8.2), CFrame = CFrame.new(0, 6.2, 0) * CFrame.Angles(math.rad(28), 0, math.rad(22)), Color = Color3.fromRGB(255, 55, 200), Transparency = 0.2, Material = Enum.Material.Neon, Parent = structureFolder })
	part({ Name = "HoloOrbitRingB", Size = Vector3.new(6.8, 0.35, 6.8), CFrame = CFrame.new(0, 6.2, 0) * CFrame.Angles(math.rad(-25), math.rad(45), math.rad(-18)), Color = Color3.fromRGB(0, 240, 255), Transparency = 0.2, Material = Enum.Material.Neon, Parent = structureFolder })

	-- Neon Walkway Light Arches along the 4 Cardinal Corridors
	for _, arch in {
		{ Pos = Vector3.new(0, 0, -56), RotY = 0, Col = Color3.fromRGB(0, 225, 255) },
		{ Pos = Vector3.new(0, 0, 56), RotY = 0, Col = Color3.fromRGB(245, 55, 195) },
		{ Pos = Vector3.new(-56, 0, 0), RotY = 90, Col = Color3.fromRGB(245, 55, 195) },
		{ Pos = Vector3.new(56, 0, 0), RotY = 90, Col = Color3.fromRGB(0, 225, 255) },
	} do
		local cf = CFrame.new(arch.Pos) * CFrame.Angles(0, math.rad(arch.RotY), 0)
		for _, sx in { -10, 10 } do
			part({ Name = "ArchPillar", Size = Vector3.new(1.4, 17, 1.4), CFrame = cf * CFrame.new(sx, 8.5, 0), Color = Color3.fromRGB(28, 32, 46), Material = Enum.Material.Metal, Parent = structureFolder })
			part({ Name = "ArchNeonLeg", Size = Vector3.new(0.35, 16, 0.35), CFrame = cf * CFrame.new(sx * 0.92, 8.5, 0), Color = arch.Col, Material = Enum.Material.Neon, Parent = structureFolder })
		end
		part({ Name = "ArchHeader", Size = Vector3.new(21.4, 1.4, 1.6), CFrame = cf * CFrame.new(0, 17.5, 0), Color = Color3.fromRGB(28, 32, 46), Material = Enum.Material.Metal, Parent = structureFolder })
		part({ Name = "ArchNeonTop", Size = Vector3.new(19.6, 0.35, 0.4), CFrame = cf * CFrame.new(0, 16.7, 0), Color = arch.Col, Material = Enum.Material.Neon, Parent = structureFolder })
	end

	-- Cyber Partition Walls with Neon Edging & Holo Billboards
	for i, iw in {
		{ Size = Vector3.new(60, 18, 1.8), Pos = Vector3.new(60, 9, -24), Col = Color3.fromRGB(0, 205, 235) },
		{ Size = Vector3.new(1.8, 18, 60), Pos = Vector3.new(24, 9, -60), Col = Color3.fromRGB(225, 55, 175) },
		{ Size = Vector3.new(60, 18, 1.8), Pos = Vector3.new(-60, 9, 24), Col = Color3.fromRGB(225, 55, 175) },
		{ Size = Vector3.new(1.8, 18, 60), Pos = Vector3.new(-24, 9, 60), Col = Color3.fromRGB(0, 205, 235) },
	} do
		part({ Name = "CyberWall_" .. i, Size = iw.Size, Position = iw.Pos, Color = Color3.fromRGB(28, 32, 46), Material = Enum.Material.Metal, Parent = structureFolder })
		part({ Name = "CyberNeonCap_" .. i, Size = Vector3.new(iw.Size.X + 0.2, 0.45, iw.Size.Z + 0.2), Position = iw.Pos + Vector3.new(0, 9.2, 0), Color = iw.Col, Material = Enum.Material.Neon, Parent = structureFolder })
		part({ Name = "CyberNeonMid_" .. i, Size = Vector3.new(iw.Size.X + 0.25, 0.28, iw.Size.Z + 0.25), Position = iw.Pos + Vector3.new(0, -4.5, 0), Color = iw.Col, Material = Enum.Material.Neon, Parent = structureFolder })
	end

	createZoneSign(structureFolder, CFrame.new(60, 14.5, -24), Vector3.new(20, 3.6, 2.2), "DATA SERVER VAULT", Color3.fromRGB(16, 20, 34), Color3.fromRGB(0, 235, 255))
	createZoneSign(structureFolder, CFrame.new(-60, 14.5, 24), Vector3.new(20, 3.6, 2.2), "NEON ARCADE LOUNGE", Color3.fromRGB(24, 14, 34), Color3.fromRGB(255, 65, 205))
	createZoneSign(structureFolder, CFrame.new(24, 14.5, -60) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(18, 3.4, 2.2), "CYBER SECTOR 01", Color3.fromRGB(16, 20, 34), Color3.fromRGB(255, 65, 205))
	createZoneSign(structureFolder, CFrame.new(-24, 14.5, 60) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(18, 3.4, 2.2), "NIGHT MARKET", Color3.fromRGB(16, 20, 34), Color3.fromRGB(0, 235, 255))

	local cyanServer = function() return createServerRackModel(Color3.fromRGB(0, 215, 240)) end
	local pinkServer = function() return createServerRackModel(Color3.fromRGB(235, 55, 185)) end
	local cyberBarrelCyan = function() return createBarrelModel(Color3.fromRGB(30, 34, 46), Color3.fromRGB(0, 215, 240), true) end
	local cyberBarrelPink = function() return createBarrelModel(Color3.fromRGB(30, 34, 46), Color3.fromRGB(235, 55, 185), true) end
	local cyberCrate = function() return createCrateModel(1.0, Color3.fromRGB(38, 44, 62), Color3.fromRGB(0, 185, 235)) end

	local props: { { Build: () -> Model, Pos: Vector3, Yaw: number } } = {}
	local function add(buildFn: () -> Model, x: number, z: number, yaw: number?)
		table.insert(props, { Build = buildFn, Pos = Vector3.new(x, 0, z), Yaw = yaw or 0 })
	end

	-- 1. NE Cyber Server Data Center (~52 props)
	for i, x in { 34, 44, 54, 64, 74, 84, 94, 104 } do
		add(if i % 2 == 0 then cyanServer else pinkServer, x, -112, 0)
		add(if i % 2 == 1 then cyanServer else pinkServer, x, -88, 0)
	end
	for i, z in { -102, -92, -82, -72, -62, -52, -42 } do
		add(if i % 2 == 0 then cyanServer else pinkServer, 112, z, -90)
	end
	for idx, x in { 42, 64, 86, 102 } do
		for _, z in { -68, -44 } do
			local scr = if idx % 2 == 0 then Color3.fromRGB(0, 235, 255) else Color3.fromRGB(255, 65, 200)
			local chCol = if idx % 2 == 0 then Color3.fromRGB(0, 175, 225) else Color3.fromRGB(165, 45, 225)
			add(function() return createComputerDeskModel(scr) end, x, z, 0)
			add(function() return createOfficeChairModel(chCol) end, x, z + 4, 180)
			add(createTrashBinModel, x + 5, z, 0)
		end
	end
	add(function() return createVendingMachineModel(Color3.fromRGB(145, 35, 215)) end, 32, -104, 90)
	add(function() return createVendingMachineModel(Color3.fromRGB(0, 155, 215)) end, 32, -96, 90)
	add(function() return createFloorLampModel(Color3.fromRGB(0, 235, 255)) end, 34, -34, 0)
	add(function() return createFloorLampModel(Color3.fromRGB(255, 65, 215)) end, 96, -34, 0)

	-- 2. SW Cyber Arcade & Neon Lounge (~54 props)
	local neonArcades = {
		Color3.fromRGB(0, 245, 255),
		Color3.fromRGB(255, 55, 195),
		Color3.fromRGB(165, 65, 255),
		Color3.fromRGB(55, 255, 145),
		Color3.fromRGB(255, 205, 45),
	}
	for i, z in { 34, 42, 50, 58, 66, 74, 82, 90, 98, 106 } do
		local c = neonArcades[(i % #neonArcades) + 1]
		add(function() return createArcadeCabinetModel(c) end, -112, z, 90)
	end
	for i, x in { -104, -96, -88, -80, -72, -64, -52, -44, -36 } do
		if i <= 5 then
			local c = neonArcades[(i % #neonArcades) + 1]
			add(function() return createArcadeCabinetModel(c) end, x, 112, 180)
		else
			local vc = if i % 2 == 0 then Color3.fromRGB(145, 35, 215) else Color3.fromRGB(0, 155, 215)
			add(function() return createVendingMachineModel(vc) end, x, 112, 180)
		end
	end
	for _, cx in { -90, -64, -38 } do
		for _, cz in { 48, 82 } do
			add(createCafeTableModel, cx, cz, 0)
			add(function() return createSofaModel(Color3.fromRGB(125, 35, 175)) end, cx, cz - 7, 0)
			add(function() return createSofaModel(Color3.fromRGB(25, 135, 195)) end, cx, cz + 7, 180)
			add(function() return createFloorLampModel(Color3.fromRGB(255, 65, 215)) end, cx - 8, cz, 0)
		end
	end
	add(createTrashBinModel, -58, 112, 0)
	add(createTrashBinModel, -30, 112, 0)
	add(function() return createPlantPotModel(Color3.fromRGB(0, 225, 185)) end, -108, 30, 0)
	add(function() return createPlantPotModel(Color3.fromRGB(235, 65, 195)) end, -32, 32, 0)

	-- 3. NW & SE Cyber Cargo Sectors (~65 props)
	for _, mult in { -1, 1 } do
		-- mult = -1 is NW (-X, -Z), mult = 1 is SE (+X, +Z)
		for _, pos in {
			{ 106, 106 }, { 98, 106 }, { 90, 106 }, { 106, 96 }, { 96, 96 },
			{ 76, 106 }, { 68, 106 }, { 106, 74 }, { 106, 66 },
			{ 82, 74 }, { 74, 74 }, { 52, 92 }, { 44, 92 }, { 88, 44 },
		} do
			add(cyberCrate, pos[1] * mult, pos[2] * mult, (pos[1] * 9) % 40)
		end
		for idx, bPos in {
			{ 106, 84 }, { 102, 80 }, { 84, 98 }, { 60, 104 }, { 56, 100 },
			{ 96, 56 }, { 92, 52 }, { 68, 56 }, { 64, 52 }, { 38, 78 }, { 34, 74 }, { 42, 46 },
		} do
			add(if idx % 2 == 0 then cyberBarrelCyan else cyberBarrelPink, bPos[1] * mult, bPos[2] * mult, 0)
		end
		for _, pPos in { { 86, 86 }, { 62, 74 }, { 42, 62 }, { 76, 38 } } do
			add(createPalletStackModel, pPos[1] * mult, pPos[2] * mult, 15 * mult)
		end
		for i, sPos in { { 108, 36 }, { 108, 44 }, { 36, 108 }, { 44, 108 } } do
			add(if i % 2 == 0 then cyanServer else pinkServer, sPos[1] * mult, sPos[2] * mult, if sPos[1] > sPos[2] then -90 * mult else 0)
		end
		add(createTrafficConeModel, 28 * mult, 28 * mult, 0)
		add(createTrafficConeModel, 48 * mult, 22 * mult, 0)
		add(createTrashBinModel, 22 * mult, 52 * mult, 0)
	end

	-- 4. Center Neon Plaza & Corridors (~22 props)
	for _, p in {
		{ -18, -18 }, { 18, -18 }, { -18, 18 }, { 18, 18 },
		{ -42, 0 }, { 42, 0 }, { 0, -42 }, { 0, 42 },
	} do
		local col = if (p[1] + p[2]) % 4 == 0 then Color3.fromRGB(0, 225, 185) else Color3.fromRGB(235, 65, 195)
		add(function() return createPlantPotModel(col) end, p[1], p[2], 0)
	end
	add(function() return createSofaModel(Color3.fromRGB(45, 52, 82)) end, 0, -15, 0)
	add(function() return createSofaModel(Color3.fromRGB(45, 52, 82)) end, 0, 15, 180)
	add(function() return createSofaModel(Color3.fromRGB(45, 52, 82)) end, -15, 0, 90)
	add(function() return createSofaModel(Color3.fromRGB(45, 52, 82)) end, 15, 0, -90)
	add(createCafeTableModel, -12, -12, 0)
	add(createCafeTableModel, 12, 12, 0)
	add(function() return createVendingMachineModel(Color3.fromRGB(225, 45, 145)) end, 14, -48, 90)
	add(function() return createVendingMachineModel(Color3.fromRGB(0, 165, 225)) end, -14, 48, -90)

	return props
end

--------------------------------------------------------------------------------
-- MAP 3: HIGH SCHOOL CAMPUS (240x240 — Dense Classrooms, Cafeteria, Gym & Library)
--------------------------------------------------------------------------------
local function buildMapSchoolCampus(structureFolder: Folder): { { Build: () -> Model, Pos: Vector3, Yaw: number } }
	buildArenaShell(
		structureFolder,
		Color3.fromRGB(202, 194, 178),
		Enum.Material.SmoothPlastic,
		Color3.fromRGB(238, 232, 218),
		Color3.fromRGB(64, 98, 138),
		Color3.fromRGB(255, 250, 236),
		Enum.Material.SmoothPlastic,
		Color3.fromRGB(48, 72, 104),
		0.72
	)

	-- Classroom Wood Floor (NE), Gym Hardwood Floor (SE), Cafeteria Tile (SW), Library Carpet (NW)
	part({ Name = "ClassroomFloor", Size = Vector3.new(98, 0.1, 98), Position = Vector3.new(60, 0.05, -60), Color = Color3.fromRGB(174, 134, 92), Material = Enum.Material.WoodPlanks, Parent = structureFolder })
	part({ Name = "LibraryCarpet", Size = Vector3.new(98, 0.1, 98), Position = Vector3.new(-60, 0.05, -60), Color = Color3.fromRGB(68, 92, 118), Material = Enum.Material.Fabric, Parent = structureFolder })
	part({ Name = "GymCourtFloor", Size = Vector3.new(98, 0.1, 98), Position = Vector3.new(60, 0.05, 60), Color = Color3.fromRGB(210, 152, 82), Material = Enum.Material.Wood, Parent = structureFolder })
	part({ Name = "CafeteriaFloor", Size = Vector3.new(98, 0.1, 98), Position = Vector3.new(-60, 0.05, 60), Color = Color3.fromRGB(165, 192, 208), Material = Enum.Material.Marble, Parent = structureFolder })

	-- Gymnasium Court Markings & Basketball Hoops!
	part({ Name = "GymCenterLine", Size = Vector3.new(0.6, 0.14, 86), Position = Vector3.new(60, 0.07, 60), Color = Color3.fromRGB(245, 245, 245), Material = Enum.Material.SmoothPlastic, Parent = structureFolder })
	part({ Name = "GymCenterCircle", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.14, 18, 18), CFrame = CFrame.new(60, 0.07, 60) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(48, 112, 195), Material = Enum.Material.SmoothPlastic, Parent = structureFolder })
	part({ Name = "GymCenterInner", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.16, 15.8, 15.8), CFrame = CFrame.new(60, 0.08, 60) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(210, 152, 82), Material = Enum.Material.Wood, Parent = structureFolder })
	for _, bLine in {
		{ Size = Vector3.new(86, 0.14, 0.6), Pos = Vector3.new(60, 0.07, 17) },
		{ Size = Vector3.new(86, 0.14, 0.6), Pos = Vector3.new(60, 0.07, 103) },
		{ Size = Vector3.new(0.6, 0.14, 86), Pos = Vector3.new(17, 0.07, 60) },
		{ Size = Vector3.new(0.6, 0.14, 86), Pos = Vector3.new(103, 0.07, 60) },
	} do
		part({ Name = "GymCourtLine", Size = bLine.Size, Position = bLine.Pos, Color = Color3.fromRGB(245, 245, 245), Material = Enum.Material.SmoothPlastic, Parent = structureFolder })
	end
	for _, hoopX in { 22, 98 } do
		local dir = if hoopX == 22 then 1 else -1
		part({ Name = "HoopPole", Size = Vector3.new(0.8, 14, 0.8), Position = Vector3.new(hoopX, 7, 60), Color = Color3.fromRGB(42, 46, 54), Material = Enum.Material.Metal, Parent = structureFolder })
		part({ Name = "HoopBackboard", Size = Vector3.new(0.3, 4.6, 7.2), Position = Vector3.new(hoopX + dir * 1.4, 13.5, 60), Color = Color3.fromRGB(220, 235, 248), Transparency = 0.25, Material = Enum.Material.Glass, Parent = structureFolder })
		part({ Name = "HoopRim", Size = Vector3.new(2.2, 0.25, 2.2), Position = Vector3.new(hoopX + dir * 2.6, 12.1, 60), Color = Color3.fromRGB(235, 92, 32), Material = Enum.Material.Metal, Parent = structureFolder })
	end

	-- Framed Classroom Green Chalkboard with Chalk Math Diagram
	part({ Name = "ChalkboardFrame", Size = Vector3.new(46, 9.2, 0.5), Position = Vector3.new(64, 10, -118.6), Color = Color3.fromRGB(132, 86, 48), Material = Enum.Material.Wood, Parent = structureFolder })
	local chalkboard = part({ Name = "Chalkboard", Size = Vector3.new(44, 7.8, 0.55), Position = Vector3.new(64, 10, -118.45), Color = Color3.fromRGB(34, 82, 52), Material = Enum.Material.SmoothPlastic, Parent = structureFolder })
	createZoneSign(structureFolder, CFrame.new(64, 10, -118.1), Vector3.new(38, 6.2, 0.1), "MATH 101  |  E = mc²   a² + b² = c²\nTODAY: PROP HUNT EXAM!", Color3.fromRGB(34, 82, 52), Color3.fromRGB(230, 240, 230), Color3.fromRGB(245, 250, 242))
	local _ = chalkboard

	-- Central School Courtyard Crest & Planter Curb
	part({ Name = "SchoolCourtyardTile", Size = Vector3.new(44, 0.12, 44), Position = Vector3.new(0, 0.06, 0), Color = Color3.fromRGB(228, 222, 210), Material = Enum.Material.Marble, Parent = structureFolder })
	part({ Name = "SchoolCrestOuter", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.16, 16, 16), CFrame = CFrame.new(0, 0.08, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(48, 92, 152), Material = Enum.Material.SmoothPlastic, Parent = structureFolder })
	part({ Name = "SchoolCrestInner", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.18, 12.5, 12.5), CFrame = CFrame.new(0, 0.09, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(235, 185, 58), Material = Enum.Material.SmoothPlastic, Parent = structureFolder })

	-- School Hallway Partition Walls with Trim, Transom Windows & Signs
	for i, iw in {
		{ Size = Vector3.new(64, 18, 1.8), Pos = Vector3.new(68, 9, -12) },
		{ Size = Vector3.new(1.8, 18, 64), Pos = Vector3.new(12, 9, -68) },
		{ Size = Vector3.new(64, 18, 1.8), Pos = Vector3.new(-68, 9, 12) },
		{ Size = Vector3.new(1.8, 18, 64), Pos = Vector3.new(-12, 9, 68) },
	} do
		local isX = iw.Size.X > iw.Size.Z
		local wallLen = math.max(iw.Size.X, iw.Size.Z)
		part({
			Name = "SchoolWallLower_" .. i,
			Size = if isX then Vector3.new(wallLen, 9.4, 1.8) else Vector3.new(1.8, 9.4, wallLen),
			Position = Vector3.new(iw.Pos.X, 4.7, iw.Pos.Z),
			Color = Color3.fromRGB(214, 206, 192),
			Material = Enum.Material.Concrete,
			Parent = structureFolder,
		})
		part({
			Name = "SchoolWallUpper_" .. i,
			Size = if isX then Vector3.new(wallLen, 3.8, 1.8) else Vector3.new(1.8, 3.8, wallLen),
			Position = Vector3.new(iw.Pos.X, 16.1, iw.Pos.Z),
			Color = Color3.fromRGB(214, 206, 192),
			Material = Enum.Material.Concrete,
			Parent = structureFolder,
		})
		part({
			Name = "SchoolHallGlass_" .. i,
			Size = if isX then Vector3.new(wallLen - 3, 4.8, 0.45) else Vector3.new(0.45, 4.8, wallLen - 3),
			Position = Vector3.new(iw.Pos.X, 11.8, iw.Pos.Z),
			Color = Color3.fromRGB(145, 198, 232),
			Transparency = 0.48,
			Material = Enum.Material.Glass,
			Parent = structureFolder,
		})
		part({ Name = "SchoolWallTrim_" .. i, Size = Vector3.new(iw.Size.X + 0.3, 3.6, iw.Size.Z + 0.3), Position = Vector3.new(iw.Pos.X, 1.8, iw.Pos.Z), Color = Color3.fromRGB(64, 98, 138), Material = Enum.Material.SmoothPlastic, Parent = structureFolder })
		part({ Name = "SchoolWallCap_" .. i, Size = Vector3.new(iw.Size.X + 0.4, 0.65, iw.Size.Z + 0.4), Position = Vector3.new(iw.Pos.X, 18.2, iw.Pos.Z), Color = Color3.fromRGB(132, 88, 52), Material = Enum.Material.Wood, Parent = structureFolder })
	end

	createZoneSign(structureFolder, CFrame.new(68, 15.2, -12), Vector3.new(18, 3.2, 2.2), "CLASSROOMS", Color3.fromRGB(42, 72, 112), Color3.fromRGB(255, 215, 85))
	createZoneSign(structureFolder, CFrame.new(12, 15.2, -68) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(18, 3.2, 2.2), "LIBRARY & LOCKERS", Color3.fromRGB(42, 72, 112), Color3.fromRGB(120, 215, 255))
	createZoneSign(structureFolder, CFrame.new(-68, 15.2, 12), Vector3.new(18, 3.2, 2.2), "CAFETERIA", Color3.fromRGB(38, 95, 78), Color3.fromRGB(255, 215, 85))
	createZoneSign(structureFolder, CFrame.new(-12, 15.2, 68) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(18, 3.2, 2.2), "GYMNASIUM", Color3.fromRGB(145, 52, 48), Color3.fromRGB(255, 215, 85))

	local blueLocker = function() return createSchoolLockerModel(Color3.fromRGB(48, 118, 195)) end
	local redLocker = function() return createSchoolLockerModel(Color3.fromRGB(195, 58, 58)) end

	local props: { { Build: () -> Model, Pos: Vector3, Yaw: number } } = {}
	local function add(buildFn: () -> Model, x: number, z: number, yaw: number?)
		table.insert(props, { Build = buildFn, Pos = Vector3.new(x, 0, z), Yaw = yaw or 0 })
	end

	-- 1. NE Lecture Classrooms (~50 props: 30 student desks in 6x5 grid + teacher desks + bookshelves)
	add(createComputerDeskModel, 48, -108, 180)
	add(createOfficeChairModel, 48, -113, 0)
	add(createComputerDeskModel, 82, -108, 180)
	add(createOfficeChairModel, 82, -113, 0)
	for _, x in { 28, 42, 56, 72, 86, 100 } do
		for _, z in { -92, -78, -64, -50, -34 } do
			add(createSchoolDeskModel, x, z, 0)
		end
	end
	for _, z in { -102, -88, -74, -60, -46, -32 } do
		add(createBookshelfModel, 113, z, -90)
	end
	for _, z in { -98, -86, -74, -62 } do
		add(createFilingCabinetModel, 17, z, 90)
	end
	add(createTrashBinModel, 22, -108, 0)
	add(createTrashBinModel, 106, -108, 0)
	add(createWaterCoolerModel, 106, -22, 180)
	add(createPlantPotModel, 20, -22, 0)

	-- 2. NW School Library & Locker Corridors (~52 props)
	for i, x in { -104, -96, -88, -80, -72, -64, -56, -48, -40, -32, -24 } do
		add(if i % 2 == 0 then blueLocker else redLocker, x, -114, 0)
	end
	for _, z in { -102, -90, -78, -66, -54, -42, -30 } do
		add(createBookshelfModel, -113, z, 90)
	end
	for _, x in { -88, -64, -40 } do
		add(createBookshelfModel, x, -88, 0)
		add(createBookshelfModel, x, -64, 0)
		add(createComputerDeskModel, x, -42, 0)
		add(createOfficeChairModel, x, -37, 180)
		add(createSchoolDeskModel, x, -24, 0)
	end
	for _, z in { -96, -88, -80, -72, -64, -56, -48 } do
		add(if z % 16 == 0 then blueLocker else redLocker, 7, z, -90)
	end
	add(createFilingCabinetModel, -102, -104, 0)
	add(createFilingCabinetModel, -96, -104, 0)
	add(createTrashBinModel, -22, -104, 0)
	add(createWaterCoolerModel, -22, -22, 0)
	add(createPlantPotModel, -104, -20, 0)

	-- 3. SW School Cafeteria & Food Court (~46 props)
	for _, x in { -96, -76, -56, -36 } do
		for _, z in { 34, 56, 78, 96 } do
			add(createPicnicTableModel, x, z, 0)
		end
	end
	for i, x in { -104, -96, -88, -80, -72, -64 } do
		local vc = if i % 2 == 0 then Color3.fromRGB(210, 45, 55) else Color3.fromRGB(45, 135, 220)
		add(function() return createVendingMachineModel(vc) end, x, 113, 180)
	end
	for _, z in { 32, 48, 64, 80, 96 } do
		add(createTrashBinModel, -112, z, 90)
	end
	for _, z in { 44, 68, 92 } do
		add(createWaterCoolerModel, -17, z, -90)
	end
	add(createCafeTableModel, -24, 34, 0)
	add(createCafeTableModel, -24, 88, 0)
	add(createPlantPotModel, -108, 20, 0)
	add(createPlantPotModel, -22, 110, 0)

	-- 4. SE Gymnasium & Athletics Equipment Bay (~48 props)
	for i, z in { 24, 32, 40, 48, 56, 64, 72, 80, 88, 96, 104 } do
		add(if i % 2 == 0 then redLocker else blueLocker, 113, z, -90)
	end
	for i, x in { 24, 32, 40, 48, 56, 64, 72, 80 } do
		add(if i % 2 == 0 then blueLocker else redLocker, x, 113, 180)
	end
	for _, x in { 34, 54, 74, 94 } do
		for _, z in { 34, 56, 78 } do
			add(createTrafficConeModel, x, z, 0)
		end
	end
	for _, pos in { { 96, 94 }, { 88, 94 }, { 96, 86 }, { 26, 94 }, { 26, 86 }, { 56, 96 } } do
		add(createCrateModel, pos[1], pos[2], 15)
	end
	add(createPalletStackModel, 82, 96, 0)
	add(createPalletStackModel, 38, 96, -15)
	add(createPicnicTableModel, 24, 44, 90)
	add(createPicnicTableModel, 24, 68, 90)
	add(createWaterCoolerModel, 18, 26, 90)
	add(createTrashBinModel, 18, 82, 90)

	-- 5. Central School Courtyard (~14 props)
	for _, p in { { -18, -18 }, { 18, -18 }, { -18, 18 }, { 18, 18 } } do
		add(createPlantPotModel, p[1], p[2], 0)
	end
	add(createPicnicTableModel, -14, 0, 90)
	add(createPicnicTableModel, 14, 0, 90)
	add(createPicnicTableModel, 0, -14, 0)
	add(createPicnicTableModel, 0, 14, 0)
	add(createTrashBinModel, -8, -8, 0)
	add(createTrashBinModel, 8, 8, 0)

	return props
end

--------------------------------------------------------------------------------
-- MAP 4: SUNSET CAMPING PARK (240x240 — Dense Forest Tents, Campfires, Picnic Tables & Pines)
--------------------------------------------------------------------------------
local function buildMapCampingPark(structureFolder: Folder): { { Build: () -> Model, Pos: Vector3, Yaw: number } }
	buildArenaShell(
		structureFolder,
		Color3.fromRGB(64, 122, 58),
		Enum.Material.Grass,
		Color3.fromRGB(115, 86, 58),
		Color3.fromRGB(78, 54, 36),
		Color3.fromRGB(255, 192, 110),
		Enum.Material.WoodPlanks,
		Color3.fromRGB(62, 42, 26),
		0.62
	)

	-- Cobblestone Crosswalk Paths with Stone Borders & Central Campfire Plaza
	part({ Name = "StonePathNSBorder", Size = Vector3.new(20, 0.08, MAP_SIZE - 8), Position = Vector3.new(0, 0.04, 0), Color = Color3.fromRGB(98, 94, 88), Material = Enum.Material.Slate, Parent = structureFolder })
	part({ Name = "StonePathNS", Size = Vector3.new(17.6, 0.11, MAP_SIZE - 8), Position = Vector3.new(0, 0.055, 0), Color = Color3.fromRGB(145, 140, 132), Material = Enum.Material.Cobblestone, Parent = structureFolder })
	part({ Name = "StonePathEWBorder", Size = Vector3.new(MAP_SIZE - 8, 0.08, 20), Position = Vector3.new(0, 0.04, 0), Color = Color3.fromRGB(98, 94, 88), Material = Enum.Material.Slate, Parent = structureFolder })
	part({ Name = "StonePathEW", Size = Vector3.new(MAP_SIZE - 8, 0.11, 17.6), Position = Vector3.new(0, 0.055, 0), Color = Color3.fromRGB(145, 140, 132), Material = Enum.Material.Cobblestone, Parent = structureFolder })
	part({ Name = "CenterStoneCircle", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.14, 52, 52), CFrame = CFrame.new(0, 0.07, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(152, 146, 136), Material = Enum.Material.Cobblestone, Parent = structureFolder })

	-- Scenic Creek Stream & Arched Wooden Footbridge (West-South Scenic Water Feature)
	part({ Name = "CreekBed", Size = Vector3.new(12, 0.14, 86), Position = Vector3.new(-22, 0.07, -64), Color = Color3.fromRGB(82, 78, 70), Material = Enum.Material.Rock, Parent = structureFolder })
	part({ Name = "CreekWater", Size = Vector3.new(9.5, 0.18, 84), Position = Vector3.new(-22, 0.11, -64), Color = Color3.fromRGB(58, 158, 212), Transparency = 0.25, Material = Enum.Material.Glass, Parent = structureFolder })
	-- Wooden Footbridge across the creek
	part({ Name = "CreekBridgeDeck", Size = Vector3.new(15, 0.5, 8.5), Position = Vector3.new(-22, 0.6, -64), Color = Color3.fromRGB(132, 86, 48), Material = Enum.Material.WoodPlanks, Parent = structureFolder })
	for _, bz in { -68, -60 } do
		part({ Name = "BridgeRail", Size = Vector3.new(15, 0.35, 0.35), Position = Vector3.new(-22, 3.0, bz), Color = Color3.fromRGB(98, 62, 34), Material = Enum.Material.Wood, Parent = structureFolder })
		for _, bx in { -29, -22, -15 } do
			part({ Name = "BridgePost", Size = Vector3.new(0.45, 3.0, 0.45), Position = Vector3.new(bx, 1.8, bz), Color = Color3.fromRGB(98, 62, 34), Material = Enum.Material.Wood, Parent = structureFolder })
		end
	end

	-- Warm Lantern Lamp Posts along the Main Campfire Paths
	for _, lp in {
		{ -11, -34 }, { 11, -34 }, { -11, 34 }, { 11, 34 },
		{ -34, -11 }, { -34, 11 }, { 34, -11 }, { 34, 11 },
	} do
		part({ Name = "CampLampPost", Size = Vector3.new(0.55, 10, 0.55), Position = Vector3.new(lp[1], 5, lp[2]), Color = Color3.fromRGB(88, 58, 34), Material = Enum.Material.Wood, Parent = structureFolder })
		local bulb = part({ Name = "CampLampBulb", Shape = Enum.PartType.Ball, Size = Vector3.new(1.3, 1.3, 1.3), Position = Vector3.new(lp[1], 10.4, lp[2]), Color = Color3.fromRGB(255, 208, 115), Material = Enum.Material.Neon, Parent = structureFolder })
		attachLight(bulb, Color3.fromRGB(255, 195, 95), 0.75, 28)
	end

	-- Rustic Timber Fence Dividers with Posts, Rails & Camp Welcome Signboards
	for i, fw in {
		{ Size = Vector3.new(48, 8, 1.5), Pos = Vector3.new(64, 4.0, -22) },
		{ Size = Vector3.new(1.5, 8, 48), Pos = Vector3.new(-22, 4.0, 64) },
		{ Size = Vector3.new(48, 8, 1.5), Pos = Vector3.new(-64, 4.0, -22) },
		{ Size = Vector3.new(1.5, 8, 48), Pos = Vector3.new(22, 4.0, 64) },
	} do
		part({ Name = "TimberWall_" .. i, Size = fw.Size, Position = fw.Pos, Color = Color3.fromRGB(118, 78, 44), Material = Enum.Material.WoodPlanks, Parent = structureFolder })
		part({ Name = "TimberCap_" .. i, Size = Vector3.new(fw.Size.X + 0.5, 0.8, fw.Size.Z + 0.5), Position = Vector3.new(fw.Pos.X, 8.3, fw.Pos.Z), Color = Color3.fromRGB(78, 52, 30), Material = Enum.Material.Wood, Parent = structureFolder })
	end

	createZoneSign(structureFolder, CFrame.new(64, 10.2, -22), Vector3.new(18, 3.0, 1.8), "PINEWOOD CAMP", Color3.fromRGB(68, 46, 28), Color3.fromRGB(255, 205, 110))
	createZoneSign(structureFolder, CFrame.new(-64, 10.2, -22), Vector3.new(18, 3.0, 1.8), "CREEK CROSSING", Color3.fromRGB(68, 46, 28), Color3.fromRGB(125, 220, 255))
	createZoneSign(structureFolder, CFrame.new(-22, 10.2, 64) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(18, 3.0, 1.8), "RANGER OUTPOST", Color3.fromRGB(68, 46, 28), Color3.fromRGB(130, 235, 140))
	createZoneSign(structureFolder, CFrame.new(22, 10.2, 64) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(18, 3.0, 1.8), "CAMPFIRE GROVE", Color3.fromRGB(68, 46, 28), Color3.fromRGB(255, 165, 80))

	-- Decorative Wildflower & Mossy Rock Clusters (non-colliding ground detail)
	local flowerCols = { Color3.fromRGB(255, 215, 75), Color3.fromRGB(255, 115, 145), Color3.fromRGB(145, 195, 255) }
	for fIdx, fl in {
		{ -38, -32 }, { 38, -32 }, { -38, 32 }, { 38, 32 },
		{ -72, 16 }, { 72, 16 }, { -16, -78 }, { 16, 78 },
	} do
		part({ Name = "MossyBoulder", Shape = Enum.PartType.Ball, Size = Vector3.new(3.4, 2.2, 3.0), Position = Vector3.new(fl[1], 0.8, fl[2]), Color = Color3.fromRGB(110, 114, 106), Material = Enum.Material.Rock, Parent = structureFolder })
		part({ Name = "FlowerPatch", Shape = Enum.PartType.Ball, Size = Vector3.new(1.5, 0.7, 1.5), Position = Vector3.new(fl[1] + 2.0, 0.3, fl[2] + 1.2), Color = flowerCols[(fIdx % #flowerCols) + 1], Material = Enum.Material.SmoothPlastic, CanCollide = false, Parent = structureFolder })
	end

	local orangeTent = function() return createCampingTentModel(Color3.fromRGB(230, 125, 45)) end
	local greenTent = function() return createCampingTentModel(Color3.fromRGB(65, 155, 85)) end
	local blueTent = function() return createCampingTentModel(Color3.fromRGB(55, 135, 215)) end
	local redTent = function() return createCampingTentModel(Color3.fromRGB(205, 65, 65)) end
	local greenBarrel = function() return createBarrelModel(Color3.fromRGB(55, 135, 72), Color3.fromRGB(220, 195, 135)) end
	local brownBarrel = function() return createBarrelModel(Color3.fromRGB(125, 82, 48), Color3.fromRGB(215, 185, 115)) end

	local props: { { Build: () -> Model, Pos: Vector3, Yaw: number } } = {}
	local function add(buildFn: () -> Model, x: number, z: number, yaw: number?)
		table.insert(props, { Build = buildFn, Pos = Vector3.new(x, 0, z), Yaw = yaw or 0 })
	end

	-- 1. Perimeter & Quadrant Pine Forest Groves (~64 Pine Trees!)
	for _, coord in {
		-- North & South Forest Borders
		{ -108, -108 }, { -88, -110 }, { -68, -108 }, { -48, -110 }, { -28, -108 },
		{ 28, -108 }, { 48, -110 }, { 68, -108 }, { 88, -110 }, { 108, -108 },
		{ -108, 108 }, { -88, 110 }, { -68, 108 }, { -48, 110 }, { -28, 108 },
		{ 28, 108 }, { 48, 110 }, { 68, 108 }, { 88, 110 }, { 108, 108 },
		-- West & East Forest Borders
		{ -110, -88 }, { -108, -68 }, { -110, -48 }, { -108, -28 },
		{ -110, 28 }, { -108, 48 }, { -110, 68 }, { -108, 88 },
		{ 110, -88 }, { 108, -68 }, { 110, -48 }, { 108, -28 },
		{ 110, 28 }, { 108, 48 }, { 110, 68 }, { 108, 88 },
		-- Inner Woods Clusters across all 4 Quadrants
		{ -92, -92 }, { -74, -94 }, { -54, -92 }, { -94, -72 }, { -76, -74 }, { -92, -52 }, { -34, -88 },
		{ 92, -92 }, { 74, -94 }, { 54, -92 }, { 94, -52 }, { 34, -88 },
		{ -92, 92 }, { -74, 94 }, { -94, 52 }, { -34, 88 },
		{ 92, 92 }, { 74, 94 }, { 54, 92 }, { 94, 72 }, { 76, 74 }, { 92, 52 }, { 34, 88 },
	} do
		add(createPineTreeModel, coord[1], coord[2], (coord[1] * 13 + coord[2] * 7) % 360)
	end

	-- 2. Four Major Tent & Campfire Villages (NE, NW, SE, SW — ~68 props)
	local tents = { orangeTent, greenTent, blueTent, redTent }
	for qIdx, quad in { { 1, -1 }, { -1, -1 }, { 1, 1 }, { -1, 1 } } do
		local sx, sz = quad[1], quad[2]
		-- Two Campfire Circles per Quadrant
		add(createCampfireModel, 58 * sx, 58 * sz, 0)
		add(createCampfireModel, 84 * sx, 42 * sz, 0)

		-- Tents pitched around each quadrant
		add(tents[((qIdx + 0) % 4) + 1], 44 * sx, 72 * sz, 25 * sx)
		add(tents[((qIdx + 1) % 4) + 1], 72 * sx, 74 * sz, -35 * sz)
		add(tents[((qIdx + 2) % 4) + 1], 76 * sx, 46 * sz, 60 * sx)
		add(tents[((qIdx + 3) % 4) + 1], 96 * sx, 36 * sz, -20 * sz)
		add(tents[((qIdx + 1) % 4) + 1], 36 * sx, 46 * sz, 45 * sx)

		-- Picnic Tables & Camp Supplies per Quadrant
		add(createPicnicTableModel, 46 * sx, 56 * sz, 0)
		add(createPicnicTableModel, 60 * sx, 42 * sz, 90)
		add(createPicnicTableModel, 84 * sx, 62 * sz, 0)
		add(createPicnicTableModel, 36 * sx, 78 * sz, 0)

		add(createCrateModel, 52 * sx, 84 * sz, 15 * sx)
		add(createCrateModel, 46 * sx, 84 * sz, -10 * sz)
		add(createPalletStackModel, 64 * sx, 86 * sz, 20 * sx)
		add(greenBarrel, 30 * sx, 34 * sz, 0)
		add(brownBarrel, 34 * sx, 30 * sz, 0)
		add(createTrashBinModel, 28 * sx, 54 * sz, 0)
		add(createFloorLampModel, 48 * sx, 46 * sz, 0)
	end

	-- 3. Central Stone Campfire Plaza & Crosswalk Paths (~28 props)
	add(createCampfireModel, 0, -12, 0)
	add(createCampfireModel, 0, 12, 0)
	add(createPicnicTableModel, -14, 0, 90)
	add(createPicnicTableModel, 14, 0, 90)
	add(createPicnicTableModel, -14, -14, 45)
	add(createPicnicTableModel, 14, -14, -45)
	add(createPicnicTableModel, -14, 14, -45)
	add(createPicnicTableModel, 14, 14, 45)

	for _, pos in {
		{ -12, -38 }, { 12, -38 }, { -12, -68 }, { 12, -68 }, { -12, -96 }, { 12, -96 },
		{ -12, 38 }, { 12, 38 }, { -12, 68 }, { 12, 68 }, { -12, 96 }, { 12, 96 },
		{ -38, -12 }, { -38, 12 }, { 38, -12 }, { 38, 12 },
	} do
		if (pos[1] + pos[2]) % 3 == 0 then
			add(createPlantPotModel, pos[1], pos[2], 0)
		elseif (pos[1] + pos[2]) % 2 == 0 then
			add(createTrashBinModel, pos[1], pos[2], 0)
		else
			add(createTrafficConeModel, pos[1], pos[2], 0)
		end
	end

	return props
end

--------------------------------------------------------------------------------
-- MAP 5: JAPANESE SAKURA VILLAGE (240x240 — Torii Gates, Koi Pond, Tea House & Ramen Street)
--------------------------------------------------------------------------------
local function buildMapJapaneseVillage(structureFolder: Folder): { { Build: () -> Model, Pos: Vector3, Yaw: number } }
	buildArenaShell(
		structureFolder,
		Color3.fromRGB(98, 128, 76),
		Enum.Material.Grass,
		Color3.fromRGB(232, 224, 206),
		Color3.fromRGB(84, 52, 34),
		Color3.fromRGB(255, 210, 175),
		Enum.Material.SmoothPlastic,
		Color3.fromRGB(58, 38, 28),
		0.64
	)

	-- Stone Flagstone Walkways & Zoned Flooring
	part({ Name = "StoneRoadNS", Size = Vector3.new(20, 0.1, MAP_SIZE - 8), Position = Vector3.new(0, 0.05, 0), Color = Color3.fromRGB(142, 138, 134), Material = Enum.Material.Cobblestone, Parent = structureFolder })
	part({ Name = "StoneRoadEW", Size = Vector3.new(MAP_SIZE - 8, 0.1, 20), Position = Vector3.new(0, 0.05, 0), Color = Color3.fromRGB(142, 138, 134), Material = Enum.Material.Cobblestone, Parent = structureFolder })

	-- NE Tatami Tea House Floor, NW Zen Raked Sand Garden, SW Ramen Festival Plaza, SE Sakura Shrine Courtyard
	part({ Name = "TatamiFloor", Size = Vector3.new(96, 0.12, 96), Position = Vector3.new(62, 0.06, -62), Color = Color3.fromRGB(192, 186, 128), Material = Enum.Material.Fabric, Parent = structureFolder })
	part({ Name = "ZenSandGarden", Size = Vector3.new(96, 0.12, 96), Position = Vector3.new(-62, 0.06, -62), Color = Color3.fromRGB(218, 212, 198), Material = Enum.Material.Sand, Parent = structureFolder })
	part({ Name = "RamenMarketCobble", Size = Vector3.new(96, 0.12, 96), Position = Vector3.new(-62, 0.06, 62), Color = Color3.fromRGB(115, 112, 118), Material = Enum.Material.Cobblestone, Parent = structureFolder })

	-- Central Koi Pond & Arched Red Wooden Bridge
	part({ Name = "KoiPondRim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.7, 36, 36), CFrame = CFrame.new(0, 0.35, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(128, 126, 122), Material = Enum.Material.Rock, Parent = structureFolder })
	part({ Name = "KoiPondWater", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 32.5, 32.5), CFrame = CFrame.new(0, 0.42, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(52, 152, 198), Transparency = 0.2, Material = Enum.Material.Glass, Parent = structureFolder })
	-- Lily Pads & Koi Accents
	for _, lp in { { -10, -8 }, { -12, 6 }, { 10, -9 }, { 11, 8 }, { 6, 12 }, { -7, -11 } } do
		part({ Name = "LilyPad", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.14, 2.8, 2.8), CFrame = CFrame.new(lp[1], 0.78, lp[2]) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(64, 152, 72), Material = Enum.Material.SmoothPlastic, CanCollide = false, Parent = structureFolder })
	end
	-- Arched Vermilion Bridge Crossing over the Koi Pond (East-West)
	part({ Name = "BridgeCenterDeck", Size = Vector3.new(16, 0.6, 8.2), Position = Vector3.new(0, 2.6, 0), Color = Color3.fromRGB(145, 92, 54), Material = Enum.Material.WoodPlanks, Parent = structureFolder })
	part({ Name = "BridgeRampW", Size = Vector3.new(11, 0.6, 8.2), CFrame = CFrame.new(-12.5, 1.4, 0) * CFrame.Angles(0, 0, math.rad(13)), Color = Color3.fromRGB(145, 92, 54), Material = Enum.Material.WoodPlanks, Parent = structureFolder })
	part({ Name = "BridgeRampE", Size = Vector3.new(11, 0.6, 8.2), CFrame = CFrame.new(12.5, 1.4, 0) * CFrame.Angles(0, 0, math.rad(-13)), Color = Color3.fromRGB(145, 92, 54), Material = Enum.Material.WoodPlanks, Parent = structureFolder })
	for _, bz in { -3.9, 3.9 } do
		part({ Name = "RedBridgeRail", Size = Vector3.new(17, 0.45, 0.45), Position = Vector3.new(0, 5.2, bz), Color = Color3.fromRGB(205, 42, 42), Material = Enum.Material.Wood, Parent = structureFolder })
		for _, bx in { -8, 0, 8 } do
			part({ Name = "RedBridgePost", Size = Vector3.new(0.55, 2.9, 0.55), Position = Vector3.new(bx, 3.9, bz), Color = Color3.fromRGB(205, 42, 42), Material = Enum.Material.Wood, Parent = structureFolder })
			part({ Name = "GoldPostCap", Shape = Enum.PartType.Ball, Size = Vector3.new(0.75, 0.75, 0.75), Position = Vector3.new(bx, 5.5, bz), Color = Color3.fromRGB(240, 195, 65), Material = Enum.Material.Metal, Parent = structureFolder })
		end
	end

	-- 4 Grand Vermilion Torii Gates at the Cardinal Entrances!
	for _, tg in {
		{ Pos = Vector3.new(0, 0, -44), RotY = 0 },
		{ Pos = Vector3.new(0, 0, 44), RotY = 180 },
		{ Pos = Vector3.new(-44, 0, 0), RotY = 90 },
		{ Pos = Vector3.new(44, 0, 0), RotY = -90 },
	} do
		local cf = CFrame.new(tg.Pos) * CFrame.Angles(0, math.rad(tg.RotY), 0)
		for _, sx in { -7.5, 7.5 } do
			part({ Name = "ToriiBase", Size = Vector3.new(2.2, 2.0, 2.2), CFrame = cf * CFrame.new(sx, 1.0, 0), Color = Color3.fromRGB(36, 36, 40), Material = Enum.Material.Slate, Parent = structureFolder })
			part({ Name = "ToriiPillar", Shape = Enum.PartType.Cylinder, Size = Vector3.new(16, 1.5, 1.5), CFrame = cf * CFrame.new(sx, 9.5, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(212, 44, 40), Material = Enum.Material.SmoothPlastic, Parent = structureFolder })
		end
		part({ Name = "ToriiLowerBeam", Size = Vector3.new(19.5, 1.1, 1.1), CFrame = cf * CFrame.new(0, 14.2, 0), Color = Color3.fromRGB(212, 44, 40), Material = Enum.Material.SmoothPlastic, Parent = structureFolder })
		part({ Name = "ToriiTopBeam", Size = Vector3.new(23.5, 1.5, 1.8), CFrame = cf * CFrame.new(0, 17.5, 0), Color = Color3.fromRGB(212, 44, 40), Material = Enum.Material.SmoothPlastic, Parent = structureFolder })
		part({ Name = "ToriiRoofCap", Size = Vector3.new(24.5, 0.7, 2.2), CFrame = cf * CFrame.new(0, 18.5, 0), Color = Color3.fromRGB(34, 36, 42), Material = Enum.Material.Slate, Parent = structureFolder })
		part({ Name = "ToriiPlaque", Size = Vector3.new(2.4, 3.0, 0.6), CFrame = cf * CFrame.new(0, 15.8, 0), Color = Color3.fromRGB(32, 30, 34), Material = Enum.Material.Wood, Parent = structureFolder })
	end

	-- Traditional Shoji Screen Partition Walls with Dark Pagoda Eaves
	for i, sw in {
		{ Size = Vector3.new(58, 15, 1.6), Pos = Vector3.new(66, 7.5, -14) },
		{ Size = Vector3.new(1.6, 15, 58), Pos = Vector3.new(14, 7.5, -66) },
		{ Size = Vector3.new(58, 15, 1.6), Pos = Vector3.new(-66, 7.5, 14) },
		{ Size = Vector3.new(1.6, 15, 58), Pos = Vector3.new(-14, 7.5, 66) },
	} do
		part({ Name = "ShojiFrame_" .. i, Size = sw.Size, Position = sw.Pos, Color = Color3.fromRGB(82, 52, 34), Material = Enum.Material.Wood, Parent = structureFolder })
		part({ Name = "ShojiPaper_" .. i, Size = Vector3.new(sw.Size.X - 2.4, 11.5, sw.Size.Z + 0.15), Position = sw.Pos + Vector3.new(0, 0.5, 0), Color = Color3.fromRGB(248, 240, 222), Material = Enum.Material.SmoothPlastic, Parent = structureFolder })
		part({ Name = "PagodaEave_" .. i, Size = Vector3.new(sw.Size.X + 3.0, 1.2, sw.Size.Z + 3.2), Position = Vector3.new(sw.Pos.X, 15.6, sw.Pos.Z), Color = Color3.fromRGB(48, 52, 62), Material = Enum.Material.Slate, Parent = structureFolder })
	end

	createZoneSign(structureFolder, CFrame.new(66, 13.5, -14), Vector3.new(18, 3.0, 2.2), "TEA HOUSE • 茶屋", Color3.fromRGB(48, 30, 24), Color3.fromRGB(255, 185, 205))
	createZoneSign(structureFolder, CFrame.new(-66, 13.5, 14), Vector3.new(18, 3.0, 2.2), "RAMEN STREET • 屋台", Color3.fromRGB(58, 24, 24), Color3.fromRGB(255, 195, 85))
	createZoneSign(structureFolder, CFrame.new(14, 13.5, -66) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(18, 3.0, 2.2), "ZEN GARDEN • 禅庭", Color3.fromRGB(36, 48, 38), Color3.fromRGB(165, 235, 155))
	createZoneSign(structureFolder, CFrame.new(-14, 13.5, 66) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(18, 3.0, 2.2), "SAKURA SHRINE • 桜", Color3.fromRGB(58, 26, 38), Color3.fromRGB(255, 170, 205))

	local redLantern = function() return createPaperLanternStandModel(Color3.fromRGB(255, 82, 68)) end
	local goldLantern = function() return createPaperLanternStandModel(Color3.fromRGB(255, 198, 78)) end
	local pinkLantern = function() return createPaperLanternStandModel(Color3.fromRGB(255, 135, 185)) end
	local redStall = function() return createRamenStallModel(Color3.fromRGB(198, 42, 46)) end
	local blueStall = function() return createRamenStallModel(Color3.fromRGB(42, 82, 165)) end
	local woodBarrel = function() return createBarrelModel(Color3.fromRGB(132, 88, 52), Color3.fromRGB(235, 215, 175)) end

	local props: { { Build: () -> Model, Pos: Vector3, Yaw: number } } = {}
	local function add(buildFn: () -> Model, x: number, z: number, yaw: number?)
		table.insert(props, { Build = buildFn, Pos = Vector3.new(x, 0, z), Yaw = yaw or 0 })
	end

	-- 1. Perimeter & Shrine Sakura Cherry Blossom Groves (~44 Sakura Trees!)
	for _, sc in {
		{ -106, -106 }, { -82, -108 }, { -56, -106 }, { -30, -108 },
		{ 30, -108 }, { 56, -106 }, { 82, -108 }, { 106, -106 },
		{ -106, 106 }, { -82, 108 }, { -56, 106 }, { -30, 108 },
		{ 30, 108 }, { 56, 106 }, { 82, 108 }, { 106, 106 },
		{ -108, -80 }, { -106, -54 }, { -108, -28 }, { -108, 28 }, { -106, 54 }, { -108, 80 },
		{ 108, -80 }, { 106, -54 }, { 108, -28 }, { 108, 28 }, { 106, 54 }, { 108, 80 },
		-- SE Sakura Grove Cluster
		{ 42, 42 }, { 64, 40 }, { 86, 44 }, { 44, 68 }, { 68, 66 }, { 90, 68 },
		{ 46, 90 }, { 72, 90 }, { 92, 90 },
		-- Central Courtyard Corner Sakuras
		{ -28, -28 }, { 28, -28 }, { -28, 28 }, { 28, 28 },
	} do
		local scale = if (sc[1] + sc[2]) % 3 == 0 then 1.15 else 0.95
		add(function() return createSakuraTreeModel(scale) end, sc[1], sc[2], (sc[1] * 11 + sc[2] * 7) % 360)
	end

	-- 2. NE Traditional Tatami Tea House (~44 props)
	for _, x in { 32, 54, 76, 94 } do
		for _, z in { -92, -68, -42 } do
			add(createTeaTableModel, x, z, 0)
			if (x + z) % 4 == 0 then
				add(goldLantern, x + 7, z - 4, 0)
			else
				add(createBambooClusterModel, x - 7, z + 4, 90)
			end
		end
	end
	for _, x in { 36, 56, 76, 96 } do
		add(createBookshelfModel, x, -104, 0)
	end
	for _, z in { -94, -74, -54, -34 } do
		add(createStoneLanternModel, 20, z, 90)
	end
	add(createPlantPotModel, 98, -24, 0)
	add(createPlantPotModel, 24, -24, 0)

	-- 3. NW Bamboo Zen Garden (~42 props)
	for _, x in { -94, -74, -54, -34 } do
		for _, z in { -92, -68, -44 } do
			add(createBambooClusterModel, x, z, (x * 7) % 90)
			if (x + z) % 3 == 0 then
				add(createStoneLanternModel, x + 8, z + 6, 0)
			else
				add(createTeaTableModel, x + 6, z - 6, 0)
			end
		end
	end
	for _, z in { -94, -74, -54, -34 } do
		add(pinkLantern, -20, z, -90)
	end

	-- 4. SW Ramen Night Market & Festival Street (~44 props)
	for i, x in { -94, -76, -58, -40 } do
		add(if i % 2 == 0 then redStall else blueStall, x, 36, 0)
		add(if i % 2 == 1 then redStall else blueStall, x, 92, 180)
		add(createPicnicTableModel, x, 64, 0)
		add(if i % 2 == 0 then redLantern else goldLantern, x + 6, 50, 0)
		add(woodBarrel, x - 6, 78, 0)
	end
	for _, z in { 32, 48, 64, 80, 96 } do
		add(createCrateModel, -100, z, 10)
		add(createTrashBinModel, -22, z, 0)
	end
	add(createVendingMachineModel, -26, 104, 180)
	add(createVendingMachineModel, -34, 104, 180)

	-- 5. SE Shrine Stone Lanterns & Festival Walkways (~24 props)
	for _, sl in {
		{ 32, 32 }, { 56, 32 }, { 80, 32 }, { 32, 56 }, { 56, 56 }, { 80, 56 },
		{ 32, 80 }, { 56, 80 }, { 80, 80 },
	} do
		add(createStoneLanternModel, sl[1], sl[2], 0)
		add(if (sl[1] + sl[2]) % 4 == 0 then redLantern else pinkLantern, sl[1] + 6, sl[2] + 6, 0)
	end
	add(redStall, 56, 22, 0)
	add(blueStall, 80, 22, 0)
	add(woodBarrel, 24, 48, 0)
	add(woodBarrel, 24, 72, 0)
	add(createBambooClusterModel, 98, 22, 0)
	add(createBambooClusterModel, 22, 98, 0)

	return props
end

--------------------------------------------------------------------------------
-- MAP 6: MEDIEVAL CASTLE COURTYARD (240x240 — Banquet Hall, Wizard Library, Armory & Market)
--------------------------------------------------------------------------------
local function buildMapMedievalCastle(structureFolder: Folder): { { Build: () -> Model, Pos: Vector3, Yaw: number } }
	buildArenaShell(
		structureFolder,
		Color3.fromRGB(118, 114, 108),
		Enum.Material.Cobblestone,
		Color3.fromRGB(132, 128, 122),
		Color3.fromRGB(82, 78, 74),
		Color3.fromRGB(255, 205, 130),
		Enum.Material.Brick,
		Color3.fromRGB(64, 62, 60),
		0.56
	)

	-- Zoned Castle Flooring
	-- NE Royal Banquet Hall (Dark Oak + Crimson Velvet Carpet Runner + Throne Dais)
	part({ Name = "BanquetWoodFloor", Size = Vector3.new(96, 0.1, 96), Position = Vector3.new(62, 0.05, -62), Color = Color3.fromRGB(108, 72, 46), Material = Enum.Material.WoodPlanks, Parent = structureFolder })
	part({ Name = "RoyalCarpetGold", Size = Vector3.new(18, 0.12, 88), Position = Vector3.new(62, 0.06, -62), Color = Color3.fromRGB(215, 172, 52), Material = Enum.Material.Fabric, Parent = structureFolder })
	part({ Name = "RoyalCarpetRed", Size = Vector3.new(15, 0.14, 86), Position = Vector3.new(62, 0.07, -62), Color = Color3.fromRGB(158, 30, 40), Material = Enum.Material.Fabric, Parent = structureFolder })
	-- Royal Throne Dais at North end of Banquet Hall
	part({ Name = "ThroneDaisStep", Size = Vector3.new(26, 0.9, 14), Position = Vector3.new(62, 0.45, -108), Color = Color3.fromRGB(138, 134, 128), Material = Enum.Material.Marble, Parent = structureFolder })
	part({ Name = "ThroneSeat", Size = Vector3.new(5.2, 2.2, 4.2), Position = Vector3.new(62, 2.0, -111), Color = Color3.fromRGB(158, 30, 40), Material = Enum.Material.Fabric, Parent = structureFolder })
	part({ Name = "ThroneBack", Size = Vector3.new(5.4, 7.6, 1.0), Position = Vector3.new(62, 5.4, -113), Color = Color3.fromRGB(215, 172, 52), Material = Enum.Material.Metal, Parent = structureFolder })

	-- NW Wizard's Alchemy Library (Deep Slate + Glowing Purple Arcane Circle!)
	part({ Name = "WizardFloor", Size = Vector3.new(96, 0.1, 96), Position = Vector3.new(-62, 0.05, -62), Color = Color3.fromRGB(58, 56, 72), Material = Enum.Material.Slate, Parent = structureFolder })
	part({ Name = "ArcaneOuterRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.14, 24, 24), CFrame = CFrame.new(-62, 0.07, -62) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(155, 85, 255), Material = Enum.Material.Neon, Parent = structureFolder })
	part({ Name = "ArcaneInnerDisk", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.16, 21.5, 21.5), CFrame = CFrame.new(-62, 0.08, -62) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(58, 56, 72), Material = Enum.Material.Slate, Parent = structureFolder })
	part({ Name = "ArcaneCoreStar", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.18, 9, 9), CFrame = CFrame.new(-62, 0.09, -62) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(175, 110, 255), Material = Enum.Material.Neon, Parent = structureFolder })

	-- SE Blacksmith Forge & Armory (Brick Hearth + Glowing Molten Furnace!)
	part({ Name = "ArmoryFloor", Size = Vector3.new(96, 0.1, 96), Position = Vector3.new(62, 0.05, 62), Color = Color3.fromRGB(78, 74, 72), Material = Enum.Material.Slate, Parent = structureFolder })
	part({ Name = "ForgeStructure", Size = Vector3.new(18, 12, 8), Position = Vector3.new(104, 6, 108), Color = Color3.fromRGB(92, 68, 58), Material = Enum.Material.Brick, Parent = structureFolder })
	local forgeFire = part({ Name = "ForgeFireGlow", Size = Vector3.new(9, 4.5, 2.2), Position = Vector3.new(104, 3.2, 104.2), Color = Color3.fromRGB(255, 110, 25), Material = Enum.Material.Neon, Parent = structureFolder })
	attachLight(forgeFire, Color3.fromRGB(255, 120, 35), 1.6, 42)
	part({ Name = "ForgeChimney", Size = Vector3.new(6, 16, 6), Position = Vector3.new(104, 20, 108), Color = Color3.fromRGB(78, 72, 68), Material = Enum.Material.Brick, Parent = structureFolder })

	-- Central Castle Courtyard Pedestal (Sword-in-the-Stone Monument!)
	part({ Name = "CourtyardStoneRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.16, 46, 46), CFrame = CFrame.new(0, 0.08, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(142, 138, 132), Material = Enum.Material.Cobblestone, Parent = structureFolder })
	part({ Name = "SwordPedestalBase", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.4, 12, 12), CFrame = CFrame.new(0, 0.7, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(122, 120, 118), Material = Enum.Material.Rock, Parent = structureFolder })
	part({ Name = "SwordRock", Shape = Enum.PartType.Ball, Size = Vector3.new(5.4, 4.0, 5.4), Position = Vector3.new(0, 2.6, 0), Color = Color3.fromRGB(98, 96, 94), Material = Enum.Material.Rock, Parent = structureFolder })
	part({ Name = "ExcaliburBlade", Size = Vector3.new(0.45, 5.6, 0.16), Position = Vector3.new(0, 6.2, 0), Color = Color3.fromRGB(220, 235, 255), Material = Enum.Material.Neon, Parent = structureFolder })
	part({ Name = "ExcaliburGuard", Size = Vector3.new(2.2, 0.35, 0.45), Position = Vector3.new(0, 8.2, 0), Color = Color3.fromRGB(240, 195, 65), Material = Enum.Material.Metal, Parent = structureFolder })
	local swordPommel = part({ Name = "ExcaliburPommel", Shape = Enum.PartType.Ball, Size = Vector3.new(0.65, 0.65, 0.65), Position = Vector3.new(0, 9.4, 0), Color = Color3.fromRGB(115, 205, 255), Material = Enum.Material.Neon, Parent = structureFolder })
	attachLight(swordPommel, Color3.fromRGB(125, 205, 255), 0.9, 32)

	-- Castle Battlement Stone Partition Walls with Crenellations & Hanging Banners!
	for i, cw in {
		{ Size = Vector3.new(60, 16, 2.2), Pos = Vector3.new(66, 8, -14), Axis = "X" },
		{ Size = Vector3.new(2.2, 16, 60), Pos = Vector3.new(14, 8, -66), Axis = "Z" },
		{ Size = Vector3.new(60, 16, 2.2), Pos = Vector3.new(-66, 8, 14), Axis = "X" },
		{ Size = Vector3.new(2.2, 16, 60), Pos = Vector3.new(-14, 8, 66), Axis = "Z" },
	} do
		part({ Name = "CastleWall_" .. i, Size = cw.Size, Position = cw.Pos, Color = Color3.fromRGB(112, 108, 104), Material = Enum.Material.Cobblestone, Parent = structureFolder })
		-- Crenellations (castle merlons along top of wall)
		for m = -24, 24, 8 do
			local mPos = if cw.Axis == "X"
				then Vector3.new(cw.Pos.X + m, 17.2, cw.Pos.Z)
				else Vector3.new(cw.Pos.X, 17.2, cw.Pos.Z + m)
			part({ Name = "CastleMerlon", Size = Vector3.new(3.6, 2.4, 2.6), Position = mPos, Color = Color3.fromRGB(124, 120, 114), Material = Enum.Material.Cobblestone, Parent = structureFolder })
		end
	end

	createZoneSign(structureFolder, CFrame.new(66, 13.8, -14), Vector3.new(20, 3.2, 2.6), "ROYAL BANQUET HALL", Color3.fromRGB(78, 20, 26), Color3.fromRGB(245, 205, 78))
	createZoneSign(structureFolder, CFrame.new(14, 13.8, -66) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(20, 3.2, 2.6), "WIZARD'S LIBRARY", Color3.fromRGB(36, 24, 62), Color3.fromRGB(185, 125, 255))
	createZoneSign(structureFolder, CFrame.new(-66, 13.8, 14), Vector3.new(20, 3.2, 2.6), "CASTLE MARKET", Color3.fromRGB(58, 44, 28), Color3.fromRGB(255, 205, 95))
	createZoneSign(structureFolder, CFrame.new(-14, 13.8, 66) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(20, 3.2, 2.6), "BLACKSMITH ARMORY", Color3.fromRGB(58, 32, 24), Color3.fromRGB(255, 145, 65))

	local redBanner = function() return createRoyalBannerStandModel(Color3.fromRGB(178, 34, 44)) end
	local blueBanner = function() return createRoyalBannerStandModel(Color3.fromRGB(42, 84, 172)) end
	local purpleBanner = function() return createRoyalBannerStandModel(Color3.fromRGB(118, 46, 175)) end
	local oakBarrel = function() return createBarrelModel(Color3.fromRGB(118, 76, 42), Color3.fromRGB(68, 68, 74)) end
	local medievalCrate = function() return createCrateModel(1.0, Color3.fromRGB(132, 88, 50), Color3.fromRGB(78, 52, 32)) end

	local props: { { Build: () -> Model, Pos: Vector3, Yaw: number } } = {}
	local function add(buildFn: () -> Model, x: number, z: number, yaw: number?)
		table.insert(props, { Build = buildFn, Pos = Vector3.new(x, 0, z), Yaw = yaw or 0 })
	end

	-- 1. NE Royal Banquet Hall (~48 props)
	for _, z in { -94, -78, -62, -46, -30 } do
		add(createPicnicTableModel, 38, z, 0)
		add(createPicnicTableModel, 86, z, 0)
		add(redBanner, 24, z, 90)
		add(redBanner, 104, z, -90)
	end
	for _, x in { 48, 76 } do
		add(createArmorStandModel, x, -98, 0)
		add(createFireBrazierModel, x, -42, 0)
		add(createFireBrazierModel, x, -74, 0)
	end
	add(createTreasureChestModel, 46, -110, 0)
	add(createTreasureChestModel, 78, -110, 0)
	add(createArmorStandModel, 32, -110, 0)
	add(createArmorStandModel, 92, -110, 0)
	add(oakBarrel, 106, -24, 0)
	add(oakBarrel, 106, -32, 0)

	-- 2. NW Wizard's Alchemy Library (~48 props)
	for _, x in { -104, -92, -80, -68, -56, -44, -32 } do
		add(createBookshelfModel, x, -112, 0)
	end
	for _, z in { -100, -88, -76, -64, -52, -40, -28 } do
		add(createBookshelfModel, -112, z, 90)
	end
	for _, pos in {
		{ -92, -92 }, { -34, -92 }, { -92, -34 }, { -34, -34 },
		{ -62, -92 }, { -62, -32 }, { -92, -62 }, { -32, -62 },
	} do
		add(createAlchemyTableModel, pos[1], pos[2], 0)
		add(createFloorLampModel, pos[1] + 5, pos[2] + 4, 0)
	end
	for _, pos in { { -78, -78 }, { -46, -78 }, { -78, -46 }, { -46, -46 } } do
		add(purpleBanner, pos[1], pos[2], 0)
		add(createTreasureChestModel, pos[1] - 4, pos[2], 45)
	end

	-- 3. SW Medieval Market Square (~48 props)
	for i, x in { -94, -74, -54, -34 } do
		add(if i % 2 == 0 then createWoodenCartModel else createRamenStallModel, x, 38, 0)
		add(if i % 2 == 1 then createWoodenCartModel else createRamenStallModel, x, 92, 180)
		add(medievalCrate, x, 64, (x * 7) % 45)
		add(oakBarrel, x + 5, 64, 0)
		add(blueBanner, x - 6, 52, 0)
	end
	for _, z in { 32, 48, 64, 80, 96 } do
		add(createPalletStackModel, -104, z, 15)
		add(createTreasureChestModel, -22, z, -90)
	end
	add(createFireBrazierModel, -64, 78, 0)
	add(createFireBrazierModel, -44, 78, 0)

	-- 4. SE Blacksmith Forge & Armory (~46 props)
	for _, x in { 32, 48, 64, 80, 96 } do
		add(createArmorStandModel, x, 32, 0)
		add(createArmorStandModel, x, 58, 180)
	end
	for _, pos in {
		{ 32, 80 }, { 42, 80 }, { 52, 80 }, { 74, 80 }, { 84, 80 },
		{ 32, 98 }, { 42, 98 }, { 64, 98 }, { 74, 98 }, { 84, 98 },
	} do
		add(if (pos[1] + pos[2]) % 3 == 0 then createTreasureChestModel else medievalCrate, pos[1], pos[2], (pos[1] * 5) % 40)
	end
	for _, bPos in { { 24, 44 }, { 24, 68 }, { 24, 90 }, { 96, 86 }, { 104, 74 }, { 104, 48 } } do
		add(oakBarrel, bPos[1], bPos[2], 0)
	end
	for _, fPos in { { 44, 46 }, { 76, 46 }, { 58, 86 }, { 92, 94 } } do
		add(createFireBrazierModel, fPos[1], fPos[2], 0)
	end
	add(createWoodenCartModel, 56, 70, 20)
	add(createWoodenCartModel, 88, 70, -20)

	-- 5. Central Courtyard Braziers, Banners & Guard Armor (~20 props)
	for _, p in { { -16, -16 }, { 16, -16 }, { -16, 16 }, { 16, 16 } } do
		add(createFireBrazierModel, p[1], p[2], 0)
		add(createArmorStandModel, p[1] * 1.4, p[2] * 1.4, 0)
	end
	add(redBanner, -14, 0, 90)
	add(redBanner, 14, 0, -90)
	add(blueBanner, 0, -14, 0)
	add(blueBanner, 0, 14, 180)
	add(createTreasureChestModel, -26, -8, 0)
	add(createTreasureChestModel, 26, 8, 180)
	add(oakBarrel, -26, 8, 0)
	add(oakBarrel, 26, -8, 0)
	add(createWoodenCartModel, 0, -34, 90)
	add(createWoodenCartModel, 0, 34, 90)

	return props
end

--------------------------------------------------------------------------------
-- MAIN MAP GENERATOR ENTRY POINT
--------------------------------------------------------------------------------
function MapBuilder.Generate(mapId: string?)
	local chosenId: string = mapId or "GrandPlaza"

	-- Destroy default Workspace.Baseplate so it never Z-fights with MainFloor at Y=0!
	local oldBaseplate = workspace:FindFirstChild("Baseplate")
	if oldBaseplate then
		oldBaseplate:Destroy()
	end

	-- Find or create top-level GameMap folder
	local mapFolder = workspace:FindFirstChild("GameMap") :: Folder?
	if not mapFolder then
		mapFolder = Instance.new("Folder")
		mapFolder.Name = "GameMap"
		mapFolder.Parent = workspace
	end

	-- Clean up ALL Arena Structure & Props folders so SkyLoungeLobby stays intact and no duplicates remain!
	for _, childName in { "Structure", "Props" } do
		while true do
			local old = mapFolder:FindFirstChild(childName)
			if not old then
				break
			end
			old:Destroy()
		end
	end

	-- Ensure permanent Sky Lounge Lobby, MapSpawns, and SeekerWaitingBox exist
	ensureSkyLoungeLobby(mapFolder)

	local existingMapSpawn = workspace:FindFirstChild("MapSpawn") :: BasePart?
	if not existingMapSpawn then
		part({
			Name = "MapSpawn",
			Size = Vector3.new(10, 0.2, 10),
			Position = Vector3.new(0, FLOOR_Y + 0.1, 22),
			Color = Color3.fromRGB(80, 175, 255),
			Transparency = 0.6,
			CanCollide = false,
			CanQuery = false,
			Material = Enum.Material.SmoothPlastic,
			Parent = workspace,
		})
	else
		existingMapSpawn.Position = Vector3.new(0, FLOOR_Y + 0.1, 22)
		existingMapSpawn.CanQuery = false
	end

	-- Create 8 distributed MapSpawns across the spacious 240x240 arena (all clear of center monuments)
	local existingSpawnsFolder = workspace:FindFirstChild("MapSpawns")
	if not existingSpawnsFolder then
		local spawnsFolder = Instance.new("Folder")
		spawnsFolder.Name = "MapSpawns"
		spawnsFolder.Parent = workspace
		for idx, spPos in {
			Vector3.new(0, FLOOR_Y + 0.2, 22),
			Vector3.new(-28, FLOOR_Y + 0.2, 0),
			Vector3.new(28, FLOOR_Y + 0.2, 0),
			Vector3.new(0, FLOOR_Y + 0.2, -28),
			Vector3.new(0, FLOOR_Y + 0.2, 28),
			Vector3.new(-42, FLOOR_Y + 0.2, -16),
			Vector3.new(42, FLOOR_Y + 0.2, 16),
			Vector3.new(-16, FLOOR_Y + 0.2, 42),
		} do
			part({
				Name = "ArenaSpawn_" .. idx,
				Size = Vector3.new(6, 0.2, 6),
				Position = spPos,
				Transparency = 1,
				CanCollide = false,
				CanQuery = false,
				Parent = spawnsFolder,
			})
		end
	else
		local spawn1 = existingSpawnsFolder:FindFirstChild("ArenaSpawn_1") :: BasePart?
		if spawn1 and spawn1:IsA("BasePart") and spawn1.Position.Magnitude < 5 then
			spawn1.Position = Vector3.new(0, FLOOR_Y + 0.2, 22)
		end
	end

	local seekerBox = workspace:FindFirstChild("SeekerWaitingBox") :: BasePart?
	if not seekerBox then
		part({
			Name = "SeekerWaitingBox",
			Size = Vector3.new(18, 1, 18),
			Position = Vector3.new(180, WALL_HEIGHT + 12, 0),
			Color = Color3.fromRGB(220, 65, 65),
			Transparency = 1,
			CanQuery = false,
			Material = Enum.Material.Metal,
			Parent = workspace,
		})
	else
		seekerBox.Position = Vector3.new(180, WALL_HEIGHT + 12, 0)
		seekerBox.Transparency = 1
		seekerBox.CanQuery = false
	end

	local structureFolder = Instance.new("Folder")
	structureFolder.Name = "Structure"
	structureFolder.Parent = mapFolder

	local propsFolder = Instance.new("Folder")
	propsFolder.Name = "Props"
	propsFolder.Parent = mapFolder

	-- Configure realistic ShadowMap Lighting, Specular Reflections, Atmosphere, ColorCorrection & SunRays per map
	Lighting.GlobalShadows = true
	pcall(function()
		(Lighting :: any).Technology = Enum.Technology.ShadowMap
	end)
	Lighting.ExposureCompensation = -0.18
	Lighting.EnvironmentDiffuseScale = 0.72
	Lighting.EnvironmentSpecularScale = 0.85

	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	if not bloom then
		bloom = Instance.new("BloomEffect")
		bloom.Name = "Bloom"
		bloom.Parent = Lighting
	end
	bloom.Enabled = true
	bloom.Intensity = 0.22
	bloom.Threshold = 2.5
	bloom.Size = 20

	local colorCorr = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if not colorCorr then
		colorCorr = Instance.new("ColorCorrectionEffect")
		colorCorr.Name = "MapColorGrading"
		colorCorr.Parent = Lighting
	end
	colorCorr.Enabled = true
	colorCorr.Brightness = 0.01
	colorCorr.Contrast = 0.12
	colorCorr.Saturation = 0.14
	colorCorr.TintColor = Color3.fromRGB(255, 255, 255)

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmosphere then
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Name = "MapAtmosphere"
		atmosphere.Parent = Lighting
	end
	atmosphere.Density = 0.18
	atmosphere.Offset = 0.22
	atmosphere.Glare = 0.12
	atmosphere.Haze = 0.55

	local sunRays = Lighting:FindFirstChildOfClass("SunRaysEffect")
	if not sunRays then
		sunRays = Instance.new("SunRaysEffect")
		sunRays.Name = "MapSunRays"
		sunRays.Parent = Lighting
	end
	sunRays.Enabled = true
	sunRays.Intensity = 0.06
	sunRays.Spread = 0.55

	-- Theme variables for Central Atrium Pillars & Bonus Clutter Props
	local pillarCol = Color3.fromRGB(48, 52, 62)
	local pillarAccent = Color3.fromRGB(195, 162, 72)
	local pillarMat: Enum.Material = Enum.Material.Metal
	local pillarAccentMat: Enum.Material = Enum.Material.SmoothPlastic
	local bonusBuilders: { () -> Model } = {
		function() return createCrateModel(1.0) end,
		createPlantPotModel,
		createTrashBinModel,
		createTrafficConeModel,
		createOfficeChairModel,
		createWaterCoolerModel,
	}

	-- Build the selected map's Arena, Lighting Mood & Prop Placements
	local placements: { { Build: () -> Model, Pos: Vector3, Yaw: number } }
	if chosenId == "CyberpunkMall" then
		Lighting.ClockTime = 21.5
		Lighting.Brightness = 1.15
		Lighting.Ambient = Color3.fromRGB(58, 46, 92)
		Lighting.OutdoorAmbient = Color3.fromRGB(42, 36, 72)
		Lighting.ColorShift_Top = Color3.fromRGB(120, 80, 220)
		bloom.Intensity = 0.42
		bloom.Threshold = 1.6
		colorCorr.Saturation = 0.22
		colorCorr.Contrast = 0.12
		colorCorr.TintColor = Color3.fromRGB(238, 240, 255)
		atmosphere.Density = 0.22
		atmosphere.Color = Color3.fromRGB(42, 30, 75)
		atmosphere.Decay = Color3.fromRGB(24, 18, 48)
		pillarCol = Color3.fromRGB(26, 30, 44)
		pillarAccent = Color3.fromRGB(0, 225, 255)
		pillarAccentMat = Enum.Material.Neon
		bonusBuilders = {
			function() return createBarrelModel(Color3.fromRGB(30, 34, 46), Color3.fromRGB(0, 215, 240), true) end,
			function() return createCrateModel(1.0, Color3.fromRGB(38, 44, 62), Color3.fromRGB(0, 185, 235)) end,
			function() return createServerRackModel(Color3.fromRGB(235, 55, 185)) end,
			function() return createPlantPotModel(Color3.fromRGB(0, 225, 185)) end,
			createTrafficConeModel,
			createTrashBinModel,
		}
		placements = buildMapCyberpunkMall(structureFolder)
	elseif chosenId == "SchoolCampus" then
		Lighting.ClockTime = 14.2
		Lighting.Brightness = 1.35
		Lighting.Ambient = Color3.fromRGB(92, 88, 82)
		Lighting.OutdoorAmbient = Color3.fromRGB(115, 118, 125)
		Lighting.ColorShift_Top = Color3.fromRGB(255, 248, 232)
		colorCorr.Saturation = 0.14
		colorCorr.TintColor = Color3.fromRGB(255, 252, 245)
		atmosphere.Density = 0.12
		atmosphere.Color = Color3.fromRGB(215, 228, 245)
		atmosphere.Decay = Color3.fromRGB(165, 185, 215)
		pillarCol = Color3.fromRGB(228, 222, 208)
		pillarAccent = Color3.fromRGB(64, 98, 138)
		pillarMat = Enum.Material.Concrete
		bonusBuilders = {
			createSchoolDeskModel,
			createTrafficConeModel,
			createTrashBinModel,
			createPlantPotModel,
			createWaterCoolerModel,
			createOfficeChairModel,
		}
		placements = buildMapSchoolCampus(structureFolder)
	elseif chosenId == "CampingPark" then
		Lighting.ClockTime = 17.5
		Lighting.Brightness = 1.25
		Lighting.Ambient = Color3.fromRGB(92, 74, 58)
		Lighting.OutdoorAmbient = Color3.fromRGB(125, 92, 66)
		Lighting.ColorShift_Top = Color3.fromRGB(255, 195, 125)
		colorCorr.Saturation = 0.18
		colorCorr.TintColor = Color3.fromRGB(255, 244, 228)
		atmosphere.Density = 0.2
		atmosphere.Color = Color3.fromRGB(245, 178, 118)
		atmosphere.Decay = Color3.fromRGB(165, 98, 62)
		pillarCol = Color3.fromRGB(98, 66, 40)
		pillarAccent = Color3.fromRGB(255, 195, 95)
		pillarMat = Enum.Material.WoodPlanks
		bonusBuilders = {
			createCampfireModel,
			createPineTreeModel,
			createCrateModel,
			createTrashBinModel,
			createPlantPotModel,
			createPicnicTableModel,
		}
		placements = buildMapCampingPark(structureFolder)
	elseif chosenId == "JapaneseVillage" then
		Lighting.ClockTime = 17.85
		Lighting.Brightness = 1.2
		Lighting.Ambient = Color3.fromRGB(102, 78, 88)
		Lighting.OutdoorAmbient = Color3.fromRGB(132, 96, 108)
		Lighting.ColorShift_Top = Color3.fromRGB(255, 190, 208)
		bloom.Intensity = 0.34
		bloom.Threshold = 1.9
		colorCorr.Saturation = 0.2
		colorCorr.TintColor = Color3.fromRGB(255, 242, 246)
		atmosphere.Density = 0.2
		atmosphere.Color = Color3.fromRGB(245, 185, 205)
		atmosphere.Decay = Color3.fromRGB(155, 88, 112)
		pillarCol = Color3.fromRGB(198, 42, 42)
		pillarAccent = Color3.fromRGB(240, 195, 65)
		pillarMat = Enum.Material.Wood
		bonusBuilders = {
			createStoneLanternModel,
			createBambooClusterModel,
			createTeaTableModel,
			function() return createPaperLanternStandModel(Color3.fromRGB(255, 82, 68)) end,
			function() return createSakuraTreeModel(0.85) end,
			createPlantPotModel,
		}
		placements = buildMapJapaneseVillage(structureFolder)
	elseif chosenId == "MedievalCastle" then
		Lighting.ClockTime = 19.2
		Lighting.Brightness = 1.05
		Lighting.Ambient = Color3.fromRGB(76, 72, 82)
		Lighting.OutdoorAmbient = Color3.fromRGB(68, 76, 98)
		Lighting.ColorShift_Top = Color3.fromRGB(255, 195, 130)
		bloom.Intensity = 0.36
		bloom.Threshold = 1.8
		colorCorr.Saturation = 0.14
		colorCorr.Contrast = 0.12
		colorCorr.TintColor = Color3.fromRGB(252, 244, 236)
		atmosphere.Density = 0.22
		atmosphere.Color = Color3.fromRGB(98, 104, 128)
		atmosphere.Decay = Color3.fromRGB(48, 50, 68)
		pillarCol = Color3.fromRGB(115, 112, 108)
		pillarAccent = Color3.fromRGB(220, 178, 62)
		pillarMat = Enum.Material.Cobblestone
		bonusBuilders = {
			createTreasureChestModel,
			createFireBrazierModel,
			createArmorStandModel,
			function() return createBarrelModel(Color3.fromRGB(118, 76, 42), Color3.fromRGB(68, 68, 74)) end,
			function() return createRoyalBannerStandModel(Color3.fromRGB(178, 34, 44)) end,
			createCrateModel,
		}
		placements = buildMapMedievalCastle(structureFolder)
	else
		chosenId = "GrandPlaza"
		Lighting.ClockTime = 13.5
		Lighting.Brightness = 1.3
		Lighting.Ambient = Color3.fromRGB(85, 90, 104)
		Lighting.OutdoorAmbient = Color3.fromRGB(108, 114, 128)
		Lighting.ColorShift_Top = Color3.fromRGB(255, 250, 240)
		colorCorr.Saturation = 0.14
		atmosphere.Density = 0.14
		atmosphere.Color = Color3.fromRGB(205, 220, 242)
		atmosphere.Decay = Color3.fromRGB(150, 170, 200)
		placements = buildMapGrandPlaza(structureFolder)
	end

	-- 4 Themed Architectural Atrium Columns (supporting the 48x48 Skylight)
	for _, sx in { -23, 23 } do
		for _, sz in { -23, 23 } do
			part({
				Name = "AtriumPillarBase",
				Size = Vector3.new(4.6, 2.2, 4.6),
				Position = Vector3.new(sx, 1.1, sz),
				Color = pillarCol:Lerp(Color3.new(0, 0, 0), 0.15),
				Material = pillarMat,
				Parent = structureFolder,
			})
			part({
				Name = "AtriumPillar",
				Size = Vector3.new(3.4, WALL_HEIGHT, 3.4),
				Position = Vector3.new(sx, WALL_HEIGHT / 2, sz),
				Color = pillarCol,
				Material = pillarMat,
				Parent = structureFolder,
			})
			part({
				Name = "AtriumPillarAccentLow",
				Size = Vector3.new(3.8, 0.7, 3.8),
				Position = Vector3.new(sx, 2.5, sz),
				Color = pillarAccent,
				Material = pillarAccentMat,
				Parent = structureFolder,
			})
			part({
				Name = "AtriumPillarAccentHigh",
				Size = Vector3.new(3.8, 0.7, 3.8),
				Position = Vector3.new(sx, WALL_HEIGHT - 2.4, sz),
				Color = pillarAccent,
				Material = pillarAccentMat,
				Parent = structureFolder,
			})
			part({
				Name = "AtriumPillarCapital",
				Size = Vector3.new(4.8, 1.8, 4.8),
				Position = Vector3.new(sx, WALL_HEIGHT - 0.9, sz),
				Color = pillarCol:Lerp(Color3.new(0, 0, 0), 0.15),
				Material = pillarMat,
				Parent = structureFolder,
			})
		end
	end

	for index, item in placements do
		local propModel = item.Build()
		propModel.Name = string.format("%s_%02d", propModel.Name, index)

		-- Organic scatter & varied rotation so props don't look like rigid grids and Hiders can blend in naturally!
		local finalPos = item.Pos
		local finalYaw = item.Yaw
		local nearOuterWall = math.abs(item.Pos.X) >= 106 or math.abs(item.Pos.Z) >= 106

		if nearOuterWall then
			-- Wall-side props: gentle lateral scatter & slight angle variation so walls still look tidy but not robotic
			local jx = if math.abs(item.Pos.X) >= 106 then (math.random() - 0.5) * 2.0 else (math.random() - 0.5) * 8.0
			local jz = if math.abs(item.Pos.Z) >= 106 then (math.random() - 0.5) * 2.0 else (math.random() - 0.5) * 8.0
			finalPos = Vector3.new(
				math.clamp(item.Pos.X + jx, -112, 112),
				item.Pos.Y,
				math.clamp(item.Pos.Z + jz, -112, 112)
			)
			if math.random() < 0.5 then
				finalYaw = (item.Yaw + math.random(-20, 20)) % 360
			end
		else
			-- Interior props: wide organic scatter (±6.5 studs) & natural rotation
			local jx = (math.random() - 0.5) * 13.0
			local jz = (math.random() - 0.5) * 13.0
			local candX = math.clamp(item.Pos.X + jx, -108, 108)
			local candZ = math.clamp(item.Pos.Z + jz, -108, 108)
			-- Keep clear of central centerpiece monument (radius 15 around origin)
			if Vector2.new(candX, candZ).Magnitude < 16 then
				local dir = Vector2.new(candX, candZ)
				if dir.Magnitude < 0.1 then
					dir = Vector2.new(1, 0)
				end
				dir = dir.Unit * 17
				candX, candZ = dir.X, dir.Y
			end
			finalPos = Vector3.new(candX, item.Pos.Y, candZ)
			if math.random() < 0.8 then
				finalYaw = (item.Yaw + math.random(-180, 180)) % 360
			end
		end

		placeMorphableProp(propModel, propsFolder, finalPos, finalYaw)
	end

	-- Spawn 45 randomized themed clutter props scattered organically across the whole 240x240 map!
	local extraClutterCount = 45
	for bIdx = 1, extraClutterCount do
		local builder = bonusBuilders[math.random(1, #bonusBuilders)]
		local bonusProp = builder()
		bonusProp.Name = string.format("%s_Bonus_%02d", bonusProp.Name, bIdx)

		local rx = math.random(-106, 106)
		local rz = math.random(-106, 106)
		-- Avoid overlapping the central monument (radius 17 around origin)
		if Vector2.new(rx, rz).Magnitude < 17 then
			local angle = math.random() * math.pi * 2
			rx = math.floor(math.cos(angle) * 20)
			rz = math.floor(math.sin(angle) * 20)
		end

		local scatterPos = Vector3.new(rx, FLOOR_Y, rz)
		placeMorphableProp(bonusProp, propsFolder, scatterPos, math.random(0, 359))
	end

	workspace:SetAttribute("ActiveMapId", chosenId)
	print(
		string.format(
			"[MapBuilder] Built Map '%s' with %d + %d scattered 'Morphable' props!",
			chosenId,
			#placements,
			extraClutterCount
		)
	)
end

return MapBuilder
