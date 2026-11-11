--!strict
-- ServerScriptService/Server/MapBuilder.luau
-- Multi-Map Procedural Builder for Prop Hunt Plaza!
-- Supports 4 Distinct Maps + Permanent Sky Lounge Observation Lobby:
--   1. "GrandPlaza"    : อาคารสำนักงาน & อาร์เคดพลาซ่า (Office, Library, Arcade Lounge & Warehouse)
--   2. "CyberpunkMall" : ห้างไซเบอร์พังก์นีออน (Futuristic Neon Mall, Server Room, Cyber Cafe & Hologram Plaza)
--   3. "SchoolCampus"  : โรงเรียนมัธยม (Classrooms, Cafeteria, Gymnasium & Library)
--   4. "CampingPark"   : แคมป์ปิ้งพาร์คยามเย็น (Forest Tents, Campfires, Picnic Area, Cabins & Pine Woods)

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")

local MapBuilder = {}

export type MapId = "GrandPlaza" | "CyberpunkMall" | "SchoolCampus" | "CampingPark"

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
		Subtitle = "เต็นท์แคมป์ปิ้ง กองไฟ ป่าสน และโต๊ะปิกนิก",
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
	model.Parent = parent
end

--------------------------------------------------------------------------------
-- SHARED & THEMED MULTI-PART PROP MODEL BUILDERS (22 DESIGNS)
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

-- 20. NEW (Camping Park Map): A-Frame Camping Tent
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

	m.PrimaryPart = floorMat
	return m
end

-- 21. NEW (Camping Park Map): Glowing Campfire & Logs
local function createCampfireModel(): Model
	local m = Instance.new("Model")
	m.Name = "CampfirePit"

	local base = part({
		Name = "AshBase",
		Size = Vector3.new(3.2, 0.25, 3.2),
		Position = Vector3.new(0, 0.125, 0),
		Color = Color3.fromRGB(75, 70, 65),
		Material = Enum.Material.Slate,
		Parent = m,
	})
	for _, angle in { 0, 60, 120 } do
		part({
			Name = "FireLog",
			Size = Vector3.new(3.0, 0.45, 0.55),
			CFrame = CFrame.new(0, 0.45, 0) * CFrame.Angles(0, math.rad(angle), 0),
			Color = Color3.fromRGB(108, 72, 42),
			Material = Enum.Material.Wood,
			Parent = m,
		})
	end
	part({
		Name = "FlameCore",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.6, 2.1, 1.6),
		Position = Vector3.new(0, 1.2, 0),
		Color = Color3.fromRGB(255, 135, 35),
		Material = Enum.Material.Neon,
		Parent = m,
	})

	m.PrimaryPart = base
	return m
end

-- 22. NEW (Camping Park Map): Wooden Picnic Table & Benches
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

-- 23. NEW (Camping Park Map): Pine Tree Prop
local function createPineTreeModel(): Model
	local m = Instance.new("Model")
	m.Name = "PineTree"

	local trunk = part({
		Name = "TreeTrunk",
		Size = Vector3.new(1.4, 3.2, 1.4),
		Position = Vector3.new(0, 1.6, 0),
		Color = Color3.fromRGB(102, 68, 42),
		Material = Enum.Material.Wood,
		Parent = m,
	})
	for idx, layer in {
		{ Y = 3.8, W = 5.2, H = 2.6 },
		{ Y = 5.8, W = 4.0, H = 2.4 },
		{ Y = 7.6, W = 2.6, H = 2.2 },
	} do
		part({
			Name = "PineLayer_" .. idx,
			Size = Vector3.new(layer.W, layer.H, layer.W),
			Position = Vector3.new(0, layer.Y, 0),
			Color = Color3.fromRGB(48, 125, 62),
			Material = Enum.Material.Grass,
			Parent = m,
		})
	end

	m.PrimaryPart = trunk
	return m
end

--------------------------------------------------------------------------------
-- PERMANENT SKY LOUNGE OBSERVATION LOBBY BUILDER
--------------------------------------------------------------------------------
local function ensureSkyLoungeLobby(mapFolder: Folder)
	if mapFolder:FindFirstChild("SkyLoungeLobby") then
		return
	end

	local lobbyY = WALL_HEIGHT + 2
	local lobbyFolder = Instance.new("Folder")
	lobbyFolder.Name = "SkyLoungeLobby"
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

	-- Main Ceiling Slabs around the 48x48 Central Glass Skylight (covers full 240x240 arena)
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
			Color = Color3.fromRGB(62, 66, 76),
			Material = Enum.Material.Metal,
			Parent = lobbyFolder,
		})
	end

	-- Spacious 88x88 Wood Promenade Deck around the 48x48 Skylight
	for _, deck in {
		{ Size = Vector3.new(88, 0.2, 20), Pos = Vector3.new(0, lobbyY + 0.1, -34) },
		{ Size = Vector3.new(88, 0.2, 20), Pos = Vector3.new(0, lobbyY + 0.1, 34) },
		{ Size = Vector3.new(20, 0.2, 48), Pos = Vector3.new(-34, lobbyY + 0.1, 0) },
		{ Size = Vector3.new(20, 0.2, 48), Pos = Vector3.new(34, lobbyY + 0.1, 0) },
	} do
		part({
			Name = "LobbyWoodDeck",
			Size = deck.Size,
			Position = deck.Pos,
			Color = Color3.fromRGB(142, 98, 64),
			Material = Enum.Material.WoodPlanks,
			Parent = lobbyFolder,
		})
	end

	-- Central 48x48 Glass Skylight Floor
	part({
		Name = "ObservationGlassFloor",
		Size = Vector3.new(48, 0.8, 48),
		Position = Vector3.new(0, WALL_HEIGHT + 1.5, 0),
		Color = Color3.fromRGB(150, 215, 255),
		Transparency = 0.6,
		Material = Enum.Material.Glass,
		Parent = lobbyFolder,
	})

	for _, border in {
		{ Size = Vector3.new(49, 0.25, 0.6), Pos = Vector3.new(0, lobbyY + 0.12, -24.2) },
		{ Size = Vector3.new(49, 0.25, 0.6), Pos = Vector3.new(0, lobbyY + 0.12, 24.2) },
		{ Size = Vector3.new(0.6, 0.25, 48), Pos = Vector3.new(-24.2, lobbyY + 0.12, 0) },
		{ Size = Vector3.new(0.6, 0.25, 48), Pos = Vector3.new(24.2, lobbyY + 0.12, 0) },
	} do
		part({
			Name = "SkylightNeonFrame",
			Size = border.Size,
			Position = border.Pos,
			Color = Color3.fromRGB(55, 155, 215),
			Material = Enum.Material.SmoothPlastic,
			Parent = lobbyFolder,
		})
	end

	for _, r in {
		{ Size = Vector3.new(88, 4.5, 0.8), Pos = Vector3.new(0, lobbyY + 2.25, -44) },
		{ Size = Vector3.new(88, 4.5, 0.8), Pos = Vector3.new(0, lobbyY + 2.25, 44) },
		{ Size = Vector3.new(0.8, 4.5, 88), Pos = Vector3.new(-44, lobbyY + 2.25, 0) },
		{ Size = Vector3.new(0.8, 4.5, 88), Pos = Vector3.new(44, lobbyY + 2.25, 0) },
	} do
		part({
			Name = "LobbyGlassRail",
			Size = r.Size,
			Position = r.Pos,
			Color = Color3.fromRGB(120, 195, 255),
			Transparency = 0.45,
			Material = Enum.Material.Glass,
			Parent = lobbyFolder,
		})
		part({
			Name = "LobbyRailTopBar",
			Size = Vector3.new(r.Size.X + 0.2, 0.35, r.Size.Z + 0.2),
			Position = r.Pos + Vector3.new(0, 2.3, 0),
			Color = Color3.fromRGB(42, 46, 56),
			Material = Enum.Material.Metal,
			Parent = lobbyFolder,
		})
	end

	for _, px in { -42, 42 } do
		for _, pz in { -42, 0, 42 } do
			part({
				Name = "LobbyPillar",
				Size = Vector3.new(2.4, 16, 2.4),
				Position = Vector3.new(px, lobbyY + 8, pz),
				Color = Color3.fromRGB(42, 46, 56),
				Material = Enum.Material.Metal,
				Parent = lobbyFolder,
			})
		end
	end
	for i = -4, 4 do
		part({
			Name = "PergolaBeam",
			Size = Vector3.new(88, 0.8, 1.4),
			Position = Vector3.new(0, lobbyY + 15.8, i * 10),
			Color = Color3.fromRGB(52, 56, 68),
			Material = Enum.Material.Metal,
			Parent = lobbyFolder,
		})
	end

	part({
		Name = "SpawnRedCarpet",
		Size = Vector3.new(14, 0.22, 16),
		Position = Vector3.new(0, lobbyY + 0.11, 33),
		Color = Color3.fromRGB(165, 38, 48),
		Material = Enum.Material.Fabric,
		Parent = lobbyFolder,
	})
	part({
		Name = "SpawnGoldBorder",
		Size = Vector3.new(14.8, 0.18, 16.8),
		Position = Vector3.new(0, lobbyY + 0.09, 33),
		Color = Color3.fromRGB(195, 155, 52),
		Material = Enum.Material.SmoothPlastic,
		Parent = lobbyFolder,
	})

	local existingSpawn = workspace:FindFirstChildOfClass("SpawnLocation")
	if existingSpawn then
		existingSpawn.Position = Vector3.new(0, lobbyY + 0.5, 34)
		existingSpawn.Size = Vector3.new(8, 0.6, 8)
		existingSpawn.Anchored = true
		existingSpawn.Neutral = true
		existingSpawn.Transparency = 1
		existingSpawn.CanCollide = true
	end

	part({
		Name = "LobbyFeatureWall",
		Size = Vector3.new(48, 13, 1.5),
		Position = Vector3.new(0, lobbyY + 6.5, -43.2),
		Color = Color3.fromRGB(28, 32, 44),
		Material = Enum.Material.SmoothPlastic,
		Parent = lobbyFolder,
	})

	local function createBoardGui(parentPart: BasePart, titleText: string, bodyText: string, accentColor: Color3)
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
			local sGui = Instance.new("SurfaceGui")
			sGui.Face = face
			sGui.LightInfluence = 0
			sGui.MaxDistance = 250
			sGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			sGui.PixelsPerStud = 35
			sGui.Parent = parentPart

			local bg = Instance.new("Frame")
			bg.Size = UDim2.fromScale(1, 1)
			bg.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
			bg.BorderSizePixel = 0
			bg.Parent = sGui

			local stroke = Instance.new("UIStroke")
			stroke.Color = accentColor
			stroke.Thickness = 4
			stroke.Parent = bg

			local header = Instance.new("TextLabel")
			header.Size = UDim2.new(1, -40, 0.26, 0)
			header.Position = UDim2.new(0, 20, 0.05, 0)
			header.BackgroundTransparency = 1
			header.Font = Enum.Font.GothamBlack
			header.TextScaled = true
			header.TextColor3 = accentColor
			header.Text = titleText
			header.Parent = bg

			local body = Instance.new("TextLabel")
			body.Size = UDim2.new(1, -50, 0.62, 0)
			body.Position = UDim2.new(0, 25, 0.33, 0)
			body.BackgroundTransparency = 1
			body.Font = Enum.Font.GothamBold
			body.TextScaled = true
			body.TextXAlignment = Enum.TextXAlignment.Left
			body.TextYAlignment = Enum.TextYAlignment.Top
			body.TextColor3 = Color3.fromRGB(235, 240, 250)
			body.Text = bodyText
			body.Parent = bg
		end
	end

	local centerBoard = part({
		Name = "CenterWelcomeBoard",
		Size = Vector3.new(16, 9, 0.4),
		Position = Vector3.new(0, lobbyY + 6.8, -42.0),
		Color = Color3.fromRGB(20, 24, 34),
		Parent = lobbyFolder,
	})
	createBoardGui(
		centerBoard,
		"PROP HUNT : 4 MAPS!",
		"• 4 แมพใหญ่พิเศษ (240x240) ให้โหวตเลือกก่อนเริ่มเกม!\n• มองทะลุกระจกใสลงไปดูแมพที่เลือกได้แบบสดๆ!\n• ชนะรอบรับ +50 Coins / ผิวปากล่อ +10 Coins",
		Color3.fromRGB(255, 210, 65)
	)

	local leftBoard = part({
		Name = "LeftHiderGuideBoard",
		Size = Vector3.new(12, 8, 0.4),
		Position = Vector3.new(-15.2, lobbyY + 6.5, -42.0),
		Color = Color3.fromRGB(20, 24, 34),
		Parent = lobbyFolder,
	})
	createBoardGui(
		leftBoard,
		"HIDER CONTROLS",
		"[Click / E] Morph Prop\n[F] ล็อกตัว  |  [V] ส่องดูเพื่อน\n[R] Rotate 45°\n[T] Taunt (+10 Coins)\n[G] Decoy  |  [Shift] Sprint",
		Color3.fromRGB(80, 195, 255)
	)

	local rightBoard = part({
		Name = "RightSeekerGuideBoard",
		Size = Vector3.new(12, 8, 0.4),
		Position = Vector3.new(15.2, lobbyY + 6.5, -42.0),
		Color = Color3.fromRGB(20, 24, 34),
		Parent = lobbyFolder,
	})
	createBoardGui(
		rightBoard,
		"SEEKER CONTROLS",
		"[Click / Tap] Attack Prop\n• Hit Hider: 50 Damage\n• Hit Fake Prop: -15 HP!\n[Q] Sonar Radar Scan\n• Win Round: +50 Coins!",
		Color3.fromRGB(255, 95, 95)
	)

	for _, pod in {
		{ Rank = "1st", H = 3.6, Z = 0, Col = Color3.fromRGB(185, 142, 42) },
		{ Rank = "2nd", H = 2.6, Z = -4.2, Col = Color3.fromRGB(135, 145, 155) },
		{ Rank = "3rd", H = 1.8, Z = 4.2, Col = Color3.fromRGB(155, 98, 55) },
	} do
		part({
			Name = "Podium_" .. pod.Rank,
			Size = Vector3.new(4, pod.H, 4),
			Position = Vector3.new(36, lobbyY + pod.H / 2, pod.Z),
			Color = pod.Col,
			Material = Enum.Material.SmoothPlastic,
			Parent = lobbyFolder,
		})
	end

	-- 5 Physical 3D Map Voting Pads along the North Promenade (step on pad to vote!)
	local votePadsFolder = Instance.new("Folder")
	votePadsFolder.Name = "MapVotePads"
	votePadsFolder.Parent = lobbyFolder

	for _, padInfo in {
		{ Id = "GrandPlaza", Label = "MAP 1\nออฟฟิศพลาซ่า", X = -18, Col = Color3.fromRGB(45, 125, 195) },
		{ Id = "CyberpunkMall", Label = "MAP 2\nไซเบอร์พังก์", X = -9, Col = Color3.fromRGB(155, 55, 205) },
		{ Id = "SchoolCampus", Label = "MAP 3\nโรงเรียนมัธยม", X = 0, Col = Color3.fromRGB(48, 155, 95) },
		{ Id = "CampingPark", Label = "MAP 4\nแคมป์ปิ้งพาร์ค", X = 9, Col = Color3.fromRGB(195, 115, 45) },
		{ Id = "Random", Label = "RANDOM\nสุ่มแมพ!", X = 18, Col = Color3.fromRGB(185, 145, 38) },
	} do
		local votePad = part({
			Name = "VotePad_" .. padInfo.Id,
			Size = Vector3.new(6.8, 0.35, 5.4),
			Position = Vector3.new(padInfo.X, lobbyY + 0.22, -31.5),
			Color = padInfo.Col,
			Material = Enum.Material.SmoothPlastic,
			Parent = votePadsFolder,
		})
		votePad:SetAttribute("MapChoice", padInfo.Id)

		local topGui = Instance.new("SurfaceGui")
		topGui.Face = Enum.NormalId.Top
		topGui.LightInfluence = 0
		topGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		topGui.PixelsPerStud = 35
		topGui.Parent = votePad

		local padFrame = Instance.new("Frame")
		padFrame.Size = UDim2.fromScale(1, 1)
		padFrame.BackgroundColor3 = Color3.fromRGB(22, 26, 36)
		padFrame.BackgroundTransparency = 0.15
		padFrame.BorderSizePixel = 0
		padFrame.Parent = topGui

		local padStroke = Instance.new("UIStroke")
		padStroke.Color = padInfo.Col
		padStroke.Thickness = 5
		padStroke.Parent = padFrame

		local padText = Instance.new("TextLabel")
		padText.Size = UDim2.new(1, -16, 1, -16)
		padText.Position = UDim2.fromOffset(8, 8)
		padText.BackgroundTransparency = 1
		padText.Font = Enum.Font.GothamBlack
		padText.TextScaled = true
		padText.TextColor3 = Color3.fromRGB(240, 245, 255)
		padText.Text = padInfo.Label
		padText.Parent = padFrame
	end

	placeLobbyDecor(createSofaModel(Color3.fromRGB(175, 58, 68)), Vector3.new(-34, lobbyY, -10), 90)
	placeLobbyDecor(createSofaModel(Color3.fromRGB(58, 115, 168)), Vector3.new(-34, lobbyY, 10), 90)
	placeLobbyDecor(createCafeTableModel(), Vector3.new(-34, lobbyY, 0), 0)
	placeLobbyDecor(createArcadeCabinetModel(Color3.fromRGB(165, 55, 245)), Vector3.new(-40, lobbyY, -32), 90)
	placeLobbyDecor(createArcadeCabinetModel(Color3.fromRGB(55, 195, 250)), Vector3.new(-40, lobbyY, -27), 90)
	placeLobbyDecor(createVendingMachineModel(Color3.fromRGB(210, 45, 55)), Vector3.new(40, lobbyY, -32), -90)
	placeLobbyDecor(createVendingMachineModel(Color3.fromRGB(45, 125, 215)), Vector3.new(40, lobbyY, -27), -90)
	placeLobbyDecor(createPlantPotModel(), Vector3.new(-26, lobbyY, 26), 0)
	placeLobbyDecor(createPlantPotModel(), Vector3.new(26, lobbyY, 26), 0)
	placeLobbyDecor(createPlantPotModel(), Vector3.new(-26, lobbyY, -26), 0)
	placeLobbyDecor(createPlantPotModel(), Vector3.new(26, lobbyY, -26), 0)
end

--------------------------------------------------------------------------------
-- ARENA SHELL BUILDER (OUTER WALLS & LIGHTS PER THEME)
--------------------------------------------------------------------------------
local function buildArenaShell(
	structureFolder: Folder,
	floorColor: Color3,
	floorMat: Enum.Material,
	wallColor: Color3,
	wainscotColor: Color3,
	windowGlowColor: Color3
)
	local half = MAP_SIZE / 2

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
			Material = Enum.Material.Concrete,
			Parent = structureFolder,
		})
	end

	part({ Name = "NorthWainscot", Size = Vector3.new(MAP_SIZE, 5, 0.4), Position = Vector3.new(0, 2.5, -half + 0.2), Color = wainscotColor, Material = Enum.Material.Wood, Parent = structureFolder })
	part({ Name = "SouthWainscot", Size = Vector3.new(MAP_SIZE, 5, 0.4), Position = Vector3.new(0, 2.5, half - 0.2), Color = wainscotColor, Material = Enum.Material.Wood, Parent = structureFolder })
	part({ Name = "EastWainscot", Size = Vector3.new(0.4, 5, MAP_SIZE), Position = Vector3.new(half - 0.2, 2.5, 0), Color = wainscotColor, Material = Enum.Material.Wood, Parent = structureFolder })
	part({ Name = "WestWainscot", Size = Vector3.new(0.4, 5, MAP_SIZE), Position = Vector3.new(-half + 0.2, 2.5, 0), Color = wainscotColor, Material = Enum.Material.Wood, Parent = structureFolder })

	for i = -4, 4 do
		local offset = i * 24
		part({ Name = "NorthWindowGlass", Size = Vector3.new(13, 8, 0.5), Position = Vector3.new(offset, 16, -half + 0.2), Color = windowGlowColor, Transparency = 0.25, Material = Enum.Material.Glass, Parent = structureFolder })
		part({ Name = "SouthWindowGlass", Size = Vector3.new(13, 8, 0.5), Position = Vector3.new(offset, 16, half - 0.2), Color = windowGlowColor, Transparency = 0.25, Material = Enum.Material.Glass, Parent = structureFolder })
		part({ Name = "EastWindowGlass", Size = Vector3.new(0.5, 8, 13), Position = Vector3.new(half - 0.2, 16, offset), Color = windowGlowColor, Transparency = 0.25, Material = Enum.Material.Glass, Parent = structureFolder })
		part({ Name = "WestWindowGlass", Size = Vector3.new(0.5, 8, 13), Position = Vector3.new(-half + 0.2, 16, offset), Color = windowGlowColor, Transparency = 0.25, Material = Enum.Material.Glass, Parent = structureFolder })
	end

	for gx = -3, 3 do
		for gz = -3, 3 do
			if not (gx == 0 and gz == 0) then
				local lx, lz = gx * 32, gz * 32
				local bulb = part({
					Name = "CeilingLight",
					Size = Vector3.new(6.0, 0.3, 2.2),
					Position = Vector3.new(lx, WALL_HEIGHT - 0.2, lz),
					Color = windowGlowColor,
					Material = Enum.Material.SmoothPlastic,
					Parent = structureFolder,
				})
				local pl = Instance.new("PointLight")
				pl.Brightness = 0.65
				pl.Range = 54
				pl.Color = windowGlowColor
				pl.Parent = bulb
			end
		end
	end
end

-- Helper to scale inner 120x120 coordinates out to the spacious 240x240 arena (1.85x spacing)
local function scaleAndMergePlacements(
	baseList: { { Build: () -> Model, Pos: Vector3, Yaw: number } },
	extraOuterList: { { Build: () -> Model, Pos: Vector3, Yaw: number } }
): { { Build: () -> Model, Pos: Vector3, Yaw: number } }
	local out = {}
	for _, item in baseList do
		table.insert(out, {
			Build = item.Build,
			Pos = Vector3.new(math.round(item.Pos.X * 1.85), item.Pos.Y, math.round(item.Pos.Z * 1.85)),
			Yaw = item.Yaw,
		})
	end
	for _, item in extraOuterList do
		table.insert(out, item)
	end
	return out
end

--------------------------------------------------------------------------------
-- MAP 1: GRAND PLAZA (240x240 — Office Wing, Library, Arcade Lounge & Mega Warehouse)
--------------------------------------------------------------------------------
local function buildMapGrandPlaza(structureFolder: Folder): { { Build: () -> Model, Pos: Vector3, Yaw: number } }
	buildArenaShell(
		structureFolder,
		Color3.fromRGB(88, 92, 102),
		Enum.Material.Concrete,
		Color3.fromRGB(218, 212, 202),
		Color3.fromRGB(115, 82, 54),
		Color3.fromRGB(255, 246, 230)
	)

	part({ Name = "OfficeWoodFloor", Size = Vector3.new(102, 0.1, 102), Position = Vector3.new(60, 0.05, -60), Color = Color3.fromRGB(152, 108, 72), Material = Enum.Material.WoodPlanks, Parent = structureFolder })
	part({ Name = "OfficeAreaRug", Size = Vector3.new(54, 0.14, 44), Position = Vector3.new(64, 0.07, -64), Color = Color3.fromRGB(48, 78, 115), Material = Enum.Material.Fabric, Parent = structureFolder })
	part({ Name = "ArcadeFloor", Size = Vector3.new(102, 0.1, 102), Position = Vector3.new(-60, 0.05, 60), Color = Color3.fromRGB(44, 52, 74), Material = Enum.Material.Fabric, Parent = structureFolder })
	part({ Name = "CenterCourtyardPad", Size = Vector3.new(56, 0.12, 56), Position = Vector3.new(0, 0.06, 0), Color = Color3.fromRGB(175, 170, 162), Material = Enum.Material.Marble, Parent = structureFolder })

	for i, iw in {
		{ Size = Vector3.new(62, 18, 1.8), Pos = Vector3.new(68, 9, -10) },
		{ Size = Vector3.new(1.8, 18, 62), Pos = Vector3.new(10, 9, -68) },
		{ Size = Vector3.new(62, 18, 1.8), Pos = Vector3.new(-68, 9, 10) },
		{ Size = Vector3.new(1.8, 18, 62), Pos = Vector3.new(-10, 9, 68) },
		{ Size = Vector3.new(42, 18, 1.8), Pos = Vector3.new(-64, 9, -42) },
		{ Size = Vector3.new(1.8, 18, 42), Pos = Vector3.new(42, 9, 64) },
	} do
		part({ Name = "PartitionWall_" .. i, Size = iw.Size, Position = iw.Pos, Color = Color3.fromRGB(198, 194, 186), Material = Enum.Material.SmoothPlastic, Parent = structureFolder })
	end

	local blueBarrel = function() return createBarrelModel(Color3.fromRGB(48, 108, 175), Color3.fromRGB(235, 235, 240)) end
	local redBarrel = function() return createBarrelModel(Color3.fromRGB(195, 55, 50), Color3.fromRGB(245, 195, 45)) end
	local greenBarrel = function() return createBarrelModel(Color3.fromRGB(55, 145, 80), Color3.fromRGB(240, 240, 240)) end

	local baseProps = {
		{ Build = createBookshelfModel, Pos = Vector3.new(14, 0, -56), Yaw = 0 },
		{ Build = createBookshelfModel, Pos = Vector3.new(21, 0, -56), Yaw = 0 },
		{ Build = createBookshelfModel, Pos = Vector3.new(28, 0, -56), Yaw = 0 },
		{ Build = createBookshelfModel, Pos = Vector3.new(35, 0, -56), Yaw = 0 },
		{ Build = createBookshelfModel, Pos = Vector3.new(56, 0, -44), Yaw = -90 },
		{ Build = createBookshelfModel, Pos = Vector3.new(56, 0, -37), Yaw = -90 },
		{ Build = createComputerDeskModel, Pos = Vector3.new(22, 0, -38), Yaw = 0 },
		{ Build = function() return createOfficeChairModel(Color3.fromRGB(45, 115, 195)) end, Pos = Vector3.new(22, 0, -34), Yaw = 180 },
		{ Build = createComputerDeskModel, Pos = Vector3.new(36, 0, -38), Yaw = 0 },
		{ Build = function() return createOfficeChairModel(Color3.fromRGB(45, 115, 195)) end, Pos = Vector3.new(36, 0, -34), Yaw = 180 },
		{ Build = createComputerDeskModel, Pos = Vector3.new(22, 0, -22), Yaw = 180 },
		{ Build = function() return createOfficeChairModel(Color3.fromRGB(50, 55, 65)) end, Pos = Vector3.new(22, 0, -26), Yaw = 0 },
		{ Build = createComputerDeskModel, Pos = Vector3.new(36, 0, -22), Yaw = 180 },
		{ Build = function() return createOfficeChairModel(Color3.fromRGB(185, 60, 65)) end, Pos = Vector3.new(36, 0, -26), Yaw = 0 },
		{ Build = createFilingCabinetModel, Pos = Vector3.new(8, 0, -52), Yaw = 90 },
		{ Build = createFilingCabinetModel, Pos = Vector3.new(8, 0, -48), Yaw = 90 },
		{ Build = createWaterCoolerModel, Pos = Vector3.new(8, 0, -26), Yaw = 90 },
		{ Build = createPlantPotModel, Pos = Vector3.new(9, 0, -56), Yaw = 0 },
		{ Build = createPlantPotModel, Pos = Vector3.new(55, 0, -55), Yaw = 45 },
		{ Build = createTrashBinModel, Pos = Vector3.new(27, 0, -38), Yaw = 0 },
		{ Build = createFloorLampModel, Pos = Vector3.new(52, 0, -24), Yaw = 0 },

		{ Build = function() return createArcadeCabinetModel(Color3.fromRGB(165, 55, 245)) end, Pos = Vector3.new(-56, 0, 14), Yaw = 90 },
		{ Build = function() return createArcadeCabinetModel(Color3.fromRGB(245, 70, 120)) end, Pos = Vector3.new(-56, 0, 19), Yaw = 90 },
		{ Build = function() return createArcadeCabinetModel(Color3.fromRGB(55, 185, 250)) end, Pos = Vector3.new(-56, 0, 24), Yaw = 90 },
		{ Build = function() return createArcadeCabinetModel(Color3.fromRGB(80, 225, 110)) end, Pos = Vector3.new(-56, 0, 29), Yaw = 90 },
		{ Build = function() return createVendingMachineModel(Color3.fromRGB(210, 45, 55)) end, Pos = Vector3.new(-48, 0, 56), Yaw = 180 },
		{ Build = function() return createVendingMachineModel(Color3.fromRGB(45, 125, 215)) end, Pos = Vector3.new(-42, 0, 56), Yaw = 180 },
		{ Build = createTrashBinModel, Pos = Vector3.new(-31, 0, 56), Yaw = 0 },
		{ Build = function() return createSofaModel(Color3.fromRGB(175, 58, 68)) end, Pos = Vector3.new(-28, 0, 22), Yaw = 0 },
		{ Build = function() return createSofaModel(Color3.fromRGB(58, 115, 168)) end, Pos = Vector3.new(-28, 0, 36), Yaw = 180 },
		{ Build = createCafeTableModel, Pos = Vector3.new(-28, 0, 29), Yaw = 0 },
		{ Build = createFloorLampModel, Pos = Vector3.new(-35, 0, 22), Yaw = 0 },
		{ Build = createPlantPotModel, Pos = Vector3.new(-55, 0, 55), Yaw = 0 },

		{ Build = function() return createCrateModel(1.0) end, Pos = Vector3.new(-52, 0, -52), Yaw = 0 },
		{ Build = function() return createCrateModel(1.0) end, Pos = Vector3.new(-47, 0, -52), Yaw = 8 },
		{ Build = function() return createCrateModel(0.85) end, Pos = Vector3.new(-52, 0, -47), Yaw = -12 },
		{ Build = createPalletStackModel, Pos = Vector3.new(-48, 0, -32), Yaw = 10 },
		{ Build = createPalletStackModel, Pos = Vector3.new(-26, 0, -38), Yaw = -20 },
		{ Build = redBarrel, Pos = Vector3.new(-40, 0, -52), Yaw = 0 },
		{ Build = blueBarrel, Pos = Vector3.new(-36, 0, -50), Yaw = 0 },
		{ Build = greenBarrel, Pos = Vector3.new(-39, 0, -47), Yaw = 0 },
		{ Build = createTrafficConeModel, Pos = Vector3.new(-32, 0, -18), Yaw = 0 },
		{ Build = createTrafficConeModel, Pos = Vector3.new(-18, 0, -18), Yaw = 0 },

		{ Build = function() return createCrateModel(1.0) end, Pos = Vector3.new(52, 0, 52), Yaw = 0 },
		{ Build = function() return createCrateModel(1.0) end, Pos = Vector3.new(47, 0, 52), Yaw = -10 },
		{ Build = createPalletStackModel, Pos = Vector3.new(44, 0, 28), Yaw = 0 },
		{ Build = blueBarrel, Pos = Vector3.new(38, 0, 52), Yaw = 0 },
		{ Build = redBarrel, Pos = Vector3.new(34, 0, 50), Yaw = 0 },
		{ Build = createTrafficConeModel, Pos = Vector3.new(18, 0, 18), Yaw = 0 },
		{ Build = createTrashBinModel, Pos = Vector3.new(18, 0, 44), Yaw = 0 },

		{ Build = createPlantPotModel, Pos = Vector3.new(-11, 0, -11), Yaw = 0 },
		{ Build = createPlantPotModel, Pos = Vector3.new(11, 0, -11), Yaw = 0 },
		{ Build = createPlantPotModel, Pos = Vector3.new(-11, 0, 11), Yaw = 0 },
		{ Build = createPlantPotModel, Pos = Vector3.new(11, 0, 11), Yaw = 0 },
		{ Build = function() return createSofaModel(Color3.fromRGB(70, 78, 92)) end, Pos = Vector3.new(0, 0, -11), Yaw = 0 },
		{ Build = function() return createSofaModel(Color3.fromRGB(70, 78, 92)) end, Pos = Vector3.new(0, 0, 11), Yaw = 180 },
	}

	local extraOuter = {
		{ Build = createComputerDeskModel, Pos = Vector3.new(86, 0, -82), Yaw = 0 },
		{ Build = createOfficeChairModel, Pos = Vector3.new(86, 0, -76), Yaw = 180 },
		{ Build = createComputerDeskModel, Pos = Vector3.new(86, 0, -54), Yaw = 180 },
		{ Build = createOfficeChairModel, Pos = Vector3.new(86, 0, -60), Yaw = 0 },
		{ Build = createBookshelfModel, Pos = Vector3.new(108, 0, -96), Yaw = -90 },
		{ Build = createBookshelfModel, Pos = Vector3.new(108, 0, -62), Yaw = -90 },
		{ Build = createCafeTableModel, Pos = Vector3.new(-76, 0, 82), Yaw = 0 },
		{ Build = function() return createSofaModel(Color3.fromRGB(165, 55, 85)) end, Pos = Vector3.new(-76, 0, 74), Yaw = 0 },
		{ Build = function() return createSofaModel(Color3.fromRGB(55, 125, 185)) end, Pos = Vector3.new(-76, 0, 90), Yaw = 180 },
		{ Build = createPalletStackModel, Pos = Vector3.new(-82, 0, -82), Yaw = 0 },
		{ Build = createPalletStackModel, Pos = Vector3.new(-62, 0, -86), Yaw = 25 },
		{ Build = createCrateModel, Pos = Vector3.new(-102, 0, -68), Yaw = 15 },
		{ Build = createPalletStackModel, Pos = Vector3.new(78, 0, 82), Yaw = -15 },
		{ Build = createCrateModel, Pos = Vector3.new(102, 0, 68), Yaw = 0 },
		{ Build = redBarrel, Pos = Vector3.new(92, 0, 88), Yaw = 0 },
		{ Build = blueBarrel, Pos = Vector3.new(-92, 0, -64), Yaw = 0 },
	}

	return scaleAndMergePlacements(baseProps, extraOuter)
end

--------------------------------------------------------------------------------
-- MAP 2: CYBERPUNK NEON MALL (240x240 — Night Mall, Server Core & Cyber Lounge)
--------------------------------------------------------------------------------
local function buildMapCyberpunkMall(structureFolder: Folder): { { Build: () -> Model, Pos: Vector3, Yaw: number } }
	buildArenaShell(
		structureFolder,
		Color3.fromRGB(24, 26, 36),
		Enum.Material.Metal,
		Color3.fromRGB(34, 38, 52),
		Color3.fromRGB(165, 35, 195),
		Color3.fromRGB(0, 205, 235)
	)

	-- Glowing Neon Floor Grid Strips across 240x240
	for i = -3, 3 do
		part({
			Name = "CyberGridLineX_" .. i,
			Size = Vector3.new(MAP_SIZE - 8, 0.1, 0.6),
			Position = Vector3.new(0, 0.05, i * 32),
			Color = Color3.fromRGB(0, 185, 225),
			Material = Enum.Material.SmoothPlastic,
			Parent = structureFolder,
		})
		part({
			Name = "CyberGridLineZ_" .. i,
			Size = Vector3.new(0.6, 0.1, MAP_SIZE - 8),
			Position = Vector3.new(i * 32, 0.05, 0),
			Color = Color3.fromRGB(205, 45, 165),
			Material = Enum.Material.SmoothPlastic,
			Parent = structureFolder,
		})
	end

	-- Cyber Partition Walls with Neon Edging
	for i, iw in {
		{ Size = Vector3.new(60, 18, 1.8), Pos = Vector3.new(60, 9, -24), Col = Color3.fromRGB(0, 205, 235) },
		{ Size = Vector3.new(1.8, 18, 60), Pos = Vector3.new(24, 9, -60), Col = Color3.fromRGB(225, 55, 175) },
		{ Size = Vector3.new(60, 18, 1.8), Pos = Vector3.new(-60, 9, 24), Col = Color3.fromRGB(225, 55, 175) },
		{ Size = Vector3.new(1.8, 18, 60), Pos = Vector3.new(-24, 9, 60), Col = Color3.fromRGB(0, 205, 235) },
	} do
		part({ Name = "CyberWall_" .. i, Size = iw.Size, Position = iw.Pos, Color = Color3.fromRGB(30, 34, 48), Material = Enum.Material.Metal, Parent = structureFolder })
		part({ Name = "CyberNeonCap_" .. i, Size = Vector3.new(iw.Size.X + 0.2, 0.4, iw.Size.Z + 0.2), Position = iw.Pos + Vector3.new(0, 9.2, 0), Color = iw.Col, Material = Enum.Material.Neon, Parent = structureFolder })
	end

	local cyanServer = function() return createServerRackModel(Color3.fromRGB(0, 215, 240)) end
	local pinkServer = function() return createServerRackModel(Color3.fromRGB(235, 55, 185)) end
	local cyberBarrelCyan = function() return createBarrelModel(Color3.fromRGB(30, 34, 46), Color3.fromRGB(0, 215, 240), true) end
	local cyberBarrelPink = function() return createBarrelModel(Color3.fromRGB(30, 34, 46), Color3.fromRGB(235, 55, 185), true) end
	local cyberCrate = function() return createCrateModel(1.0, Color3.fromRGB(38, 44, 62), Color3.fromRGB(0, 185, 235)) end

	local baseProps = {
		{ Build = cyanServer, Pos = Vector3.new(24, 0, -52), Yaw = 0 },
		{ Build = pinkServer, Pos = Vector3.new(30, 0, -52), Yaw = 0 },
		{ Build = cyanServer, Pos = Vector3.new(36, 0, -52), Yaw = 0 },
		{ Build = pinkServer, Pos = Vector3.new(42, 0, -52), Yaw = 0 },
		{ Build = cyanServer, Pos = Vector3.new(52, 0, -38), Yaw = -90 },
		{ Build = pinkServer, Pos = Vector3.new(52, 0, -30), Yaw = -90 },
		{ Build = function() return createComputerDeskModel(Color3.fromRGB(255, 65, 200)) end, Pos = Vector3.new(28, 0, -34), Yaw = 0 },
		{ Build = function() return createOfficeChairModel(Color3.fromRGB(165, 45, 225)) end, Pos = Vector3.new(28, 0, -30), Yaw = 180 },
		{ Build = function() return createComputerDeskModel(Color3.fromRGB(0, 240, 255)) end, Pos = Vector3.new(40, 0, -24), Yaw = 180 },
		{ Build = function() return createOfficeChairModel(Color3.fromRGB(0, 185, 235)) end, Pos = Vector3.new(40, 0, -28), Yaw = 0 },

		{ Build = function() return createArcadeCabinetModel(Color3.fromRGB(0, 245, 255)) end, Pos = Vector3.new(-54, 0, 20), Yaw = 90 },
		{ Build = function() return createArcadeCabinetModel(Color3.fromRGB(255, 55, 195)) end, Pos = Vector3.new(-54, 0, 25), Yaw = 90 },
		{ Build = function() return createArcadeCabinetModel(Color3.fromRGB(165, 65, 255)) end, Pos = Vector3.new(-54, 0, 30), Yaw = 90 },
		{ Build = function() return createArcadeCabinetModel(Color3.fromRGB(55, 255, 145)) end, Pos = Vector3.new(-54, 0, 35), Yaw = 90 },
		{ Build = function() return createArcadeCabinetModel(Color3.fromRGB(255, 205, 45)) end, Pos = Vector3.new(-54, 0, 40), Yaw = 90 },
		{ Build = function() return createVendingMachineModel(Color3.fromRGB(145, 35, 215)) end, Pos = Vector3.new(-46, 0, 54), Yaw = 180 },
		{ Build = function() return createVendingMachineModel(Color3.fromRGB(0, 155, 215)) end, Pos = Vector3.new(-40, 0, 54), Yaw = 180 },
		{ Build = function() return createSofaModel(Color3.fromRGB(125, 35, 175)) end, Pos = Vector3.new(-30, 0, 24), Yaw = 0 },
		{ Build = function() return createSofaModel(Color3.fromRGB(25, 135, 195)) end, Pos = Vector3.new(-30, 0, 38), Yaw = 180 },
		{ Build = createCafeTableModel, Pos = Vector3.new(-30, 0, 31), Yaw = 0 },
		{ Build = function() return createFloorLampModel(Color3.fromRGB(255, 65, 215)) end, Pos = Vector3.new(-38, 0, 24), Yaw = 0 },
		{ Build = function() return createFloorLampModel(Color3.fromRGB(0, 240, 255)) end, Pos = Vector3.new(-22, 0, 38), Yaw = 0 },

		{ Build = cyberCrate, Pos = Vector3.new(-50, 0, -50), Yaw = 0 },
		{ Build = cyberCrate, Pos = Vector3.new(-45, 0, -50), Yaw = 15 },
		{ Build = cyberCrate, Pos = Vector3.new(-50, 0, -44), Yaw = -10 },
		{ Build = cyberBarrelCyan, Pos = Vector3.new(-36, 0, -48), Yaw = 0 },
		{ Build = cyberBarrelPink, Pos = Vector3.new(-32, 0, -46), Yaw = 0 },
		{ Build = cyberBarrelCyan, Pos = Vector3.new(-28, 0, -32), Yaw = 0 },
		{ Build = cyanServer, Pos = Vector3.new(-48, 0, -24), Yaw = 90 },
		{ Build = createTrafficConeModel, Pos = Vector3.new(-22, 0, -20), Yaw = 0 },

		{ Build = cyberCrate, Pos = Vector3.new(50, 0, 50), Yaw = 0 },
		{ Build = cyberCrate, Pos = Vector3.new(44, 0, 50), Yaw = -15 },
		{ Build = cyberBarrelPink, Pos = Vector3.new(36, 0, 48), Yaw = 0 },
		{ Build = cyberBarrelCyan, Pos = Vector3.new(32, 0, 45), Yaw = 0 },
		{ Build = pinkServer, Pos = Vector3.new(48, 0, 26), Yaw = -90 },
		{ Build = function() return createVendingMachineModel(Color3.fromRGB(225, 45, 145)) end, Pos = Vector3.new(26, 0, 52), Yaw = 180 },
		{ Build = createTrashBinModel, Pos = Vector3.new(20, 0, 52), Yaw = 0 },

		{ Build = function() return createPlantPotModel(Color3.fromRGB(0, 225, 185)) end, Pos = Vector3.new(-12, 0, -12), Yaw = 0 },
		{ Build = function() return createPlantPotModel(Color3.fromRGB(235, 65, 195)) end, Pos = Vector3.new(12, 0, -12), Yaw = 0 },
		{ Build = function() return createPlantPotModel(Color3.fromRGB(235, 65, 195)) end, Pos = Vector3.new(-12, 0, 12), Yaw = 0 },
		{ Build = function() return createPlantPotModel(Color3.fromRGB(0, 225, 185)) end, Pos = Vector3.new(12, 0, 12), Yaw = 0 },
		{ Build = function() return createSofaModel(Color3.fromRGB(45, 52, 82)) end, Pos = Vector3.new(0, 0, -10), Yaw = 0 },
		{ Build = function() return createSofaModel(Color3.fromRGB(45, 52, 82)) end, Pos = Vector3.new(0, 0, 10), Yaw = 180 },
	}

	local extraOuter = {
		{ Build = cyanServer, Pos = Vector3.new(86, 0, -78), Yaw = 0 },
		{ Build = pinkServer, Pos = Vector3.new(96, 0, -78), Yaw = 0 },
		{ Build = cyanServer, Pos = Vector3.new(-78, 0, -78), Yaw = 0 },
		{ Build = pinkServer, Pos = Vector3.new(-88, 0, -78), Yaw = 0 },
		{ Build = cyberCrate, Pos = Vector3.new(-72, 0, -56), Yaw = 20 },
		{ Build = cyberCrate, Pos = Vector3.new(72, 0, 72), Yaw = -20 },
		{ Build = cyberBarrelCyan, Pos = Vector3.new(84, 0, 62), Yaw = 0 },
		{ Build = cyberBarrelPink, Pos = Vector3.new(-82, 0, 82), Yaw = 0 },
		{ Build = createCafeTableModel, Pos = Vector3.new(-74, 0, 60), Yaw = 0 },
		{ Build = function() return createSofaModel(Color3.fromRGB(125, 35, 175)) end, Pos = Vector3.new(-74, 0, 52), Yaw = 0 },
		{ Build = function() return createSofaModel(Color3.fromRGB(25, 135, 195)) end, Pos = Vector3.new(-74, 0, 68), Yaw = 180 },
	}

	return scaleAndMergePlacements(baseProps, extraOuter)
end

--------------------------------------------------------------------------------
-- MAP 3: HIGH SCHOOL CAMPUS (240x240 — Classrooms, Cafeteria, Gym & Library)
--------------------------------------------------------------------------------
local function buildMapSchoolCampus(structureFolder: Folder): { { Build: () -> Model, Pos: Vector3, Yaw: number } }
	buildArenaShell(
		structureFolder,
		Color3.fromRGB(195, 185, 168),
		Enum.Material.SmoothPlastic,
		Color3.fromRGB(232, 224, 208),
		Color3.fromRGB(72, 105, 142),
		Color3.fromRGB(255, 250, 238)
	)

	-- Classroom Wood Floor (NE), Gym Hardwood Floor (SE), Cafeteria Tile (SW) across 240x240
	part({ Name = "ClassroomFloor", Size = Vector3.new(98, 0.1, 98), Position = Vector3.new(60, 0.05, -60), Color = Color3.fromRGB(172, 132, 92), Material = Enum.Material.WoodPlanks, Parent = structureFolder })
	part({ Name = "GymCourtFloor", Size = Vector3.new(98, 0.1, 98), Position = Vector3.new(60, 0.05, 60), Color = Color3.fromRGB(205, 148, 82), Material = Enum.Material.Wood, Parent = structureFolder })
	part({ Name = "CafeteriaFloor", Size = Vector3.new(98, 0.1, 98), Position = Vector3.new(-60, 0.05, 60), Color = Color3.fromRGB(135, 165, 185), Material = Enum.Material.Marble, Parent = structureFolder })

	-- Classroom Green Chalkboard on North Wall
	part({ Name = "Chalkboard", Size = Vector3.new(38, 8, 0.4), Position = Vector3.new(60, 10, -118.5), Color = Color3.fromRGB(38, 88, 56), Material = Enum.Material.SmoothPlastic, Parent = structureFolder })

	-- School Hallway Partition Walls
	for i, iw in {
		{ Size = Vector3.new(64, 18, 1.8), Pos = Vector3.new(68, 9, -12) },
		{ Size = Vector3.new(1.8, 18, 64), Pos = Vector3.new(12, 9, -68) },
		{ Size = Vector3.new(64, 18, 1.8), Pos = Vector3.new(-68, 9, 12) },
		{ Size = Vector3.new(1.8, 18, 64), Pos = Vector3.new(-12, 9, 68) },
	} do
		part({ Name = "SchoolWall_" .. i, Size = iw.Size, Position = iw.Pos, Color = Color3.fromRGB(220, 214, 198), Material = Enum.Material.SmoothPlastic, Parent = structureFolder })
	end

	local blueLocker = function() return createSchoolLockerModel(Color3.fromRGB(48, 118, 195)) end
	local redLocker = function() return createSchoolLockerModel(Color3.fromRGB(195, 58, 58)) end

	local baseProps = {
		{ Build = createComputerDeskModel, Pos = Vector3.new(32, 0, -50), Yaw = 180 },
		{ Build = createSchoolDeskModel, Pos = Vector3.new(22, 0, -38), Yaw = 0 },
		{ Build = createSchoolDeskModel, Pos = Vector3.new(32, 0, -38), Yaw = 0 },
		{ Build = createSchoolDeskModel, Pos = Vector3.new(42, 0, -38), Yaw = 0 },
		{ Build = createSchoolDeskModel, Pos = Vector3.new(22, 0, -28), Yaw = 0 },
		{ Build = createSchoolDeskModel, Pos = Vector3.new(32, 0, -28), Yaw = 0 },
		{ Build = createSchoolDeskModel, Pos = Vector3.new(42, 0, -28), Yaw = 0 },
		{ Build = createSchoolDeskModel, Pos = Vector3.new(22, 0, -18), Yaw = 0 },
		{ Build = createSchoolDeskModel, Pos = Vector3.new(32, 0, -18), Yaw = 0 },
		{ Build = createSchoolDeskModel, Pos = Vector3.new(42, 0, -18), Yaw = 0 },
		{ Build = createBookshelfModel, Pos = Vector3.new(55, 0, -42), Yaw = -90 },
		{ Build = createBookshelfModel, Pos = Vector3.new(55, 0, -32), Yaw = -90 },
		{ Build = createTrashBinModel, Pos = Vector3.new(14, 0, -52), Yaw = 0 },
		{ Build = createWaterCoolerModel, Pos = Vector3.new(52, 0, -14), Yaw = 180 },

		{ Build = blueLocker, Pos = Vector3.new(-16, 0, -56), Yaw = 0 },
		{ Build = blueLocker, Pos = Vector3.new(-22, 0, -56), Yaw = 0 },
		{ Build = redLocker, Pos = Vector3.new(-28, 0, -56), Yaw = 0 },
		{ Build = redLocker, Pos = Vector3.new(-34, 0, -56), Yaw = 0 },
		{ Build = createBookshelfModel, Pos = Vector3.new(-54, 0, -44), Yaw = 90 },
		{ Build = createBookshelfModel, Pos = Vector3.new(-54, 0, -34), Yaw = 90 },
		{ Build = createBookshelfModel, Pos = Vector3.new(-54, 0, -24), Yaw = 90 },
		{ Build = createComputerDeskModel, Pos = Vector3.new(-34, 0, -34), Yaw = 0 },
		{ Build = createOfficeChairModel, Pos = Vector3.new(-34, 0, -30), Yaw = 180 },
		{ Build = createFilingCabinetModel, Pos = Vector3.new(-48, 0, -54), Yaw = 0 },
		{ Build = createPlantPotModel, Pos = Vector3.new(-12, 0, -14), Yaw = 0 },

		{ Build = createPicnicTableModel, Pos = Vector3.new(-42, 0, 22), Yaw = 0 },
		{ Build = createPicnicTableModel, Pos = Vector3.new(-24, 0, 22), Yaw = 0 },
		{ Build = createPicnicTableModel, Pos = Vector3.new(-42, 0, 38), Yaw = 0 },
		{ Build = createPicnicTableModel, Pos = Vector3.new(-24, 0, 38), Yaw = 0 },
		{ Build = function() return createVendingMachineModel(Color3.fromRGB(210, 45, 55)) end, Pos = Vector3.new(-52, 0, 54), Yaw = 180 },
		{ Build = function() return createVendingMachineModel(Color3.fromRGB(45, 135, 220)) end, Pos = Vector3.new(-46, 0, 54), Yaw = 180 },
		{ Build = createTrashBinModel, Pos = Vector3.new(-40, 0, 54), Yaw = 0 },
		{ Build = createWaterCoolerModel, Pos = Vector3.new(-14, 0, 52), Yaw = 180 },

		{ Build = redLocker, Pos = Vector3.new(54, 0, 18), Yaw = -90 },
		{ Build = redLocker, Pos = Vector3.new(54, 0, 24), Yaw = -90 },
		{ Build = blueLocker, Pos = Vector3.new(54, 0, 30), Yaw = -90 },
		{ Build = createTrafficConeModel, Pos = Vector3.new(22, 0, 22), Yaw = 0 },
		{ Build = createTrafficConeModel, Pos = Vector3.new(38, 0, 22), Yaw = 0 },
		{ Build = createTrafficConeModel, Pos = Vector3.new(22, 0, 42), Yaw = 0 },
		{ Build = createTrafficConeModel, Pos = Vector3.new(38, 0, 42), Yaw = 0 },
		{ Build = createCrateModel, Pos = Vector3.new(48, 0, 50), Yaw = 12 },
		{ Build = createTrashBinModel, Pos = Vector3.new(16, 0, 50), Yaw = 0 },
	}

	local extraOuter = {
		{ Build = createSchoolDeskModel, Pos = Vector3.new(92, 0, -70), Yaw = 0 },
		{ Build = createSchoolDeskModel, Pos = Vector3.new(92, 0, -52), Yaw = 0 },
		{ Build = createSchoolDeskModel, Pos = Vector3.new(92, 0, -34), Yaw = 0 },
		{ Build = createBookshelfModel, Pos = Vector3.new(-76, 0, -82), Yaw = 0 },
		{ Build = createBookshelfModel, Pos = Vector3.new(-58, 0, -82), Yaw = 0 },
		{ Build = createPicnicTableModel, Pos = Vector3.new(-92, 0, 42), Yaw = 0 },
		{ Build = createPicnicTableModel, Pos = Vector3.new(-92, 0, 72), Yaw = 0 },
		{ Build = blueLocker, Pos = Vector3.new(108, 0, 68), Yaw = -90 },
		{ Build = redLocker, Pos = Vector3.new(108, 0, 76), Yaw = -90 },
		{ Build = createPalletStackModel, Pos = Vector3.new(84, 0, 88), Yaw = 0 },
	}

	return scaleAndMergePlacements(baseProps, extraOuter)
end

--------------------------------------------------------------------------------
-- MAP 4: SUNSET CAMPING PARK (240x240 — Forest Tents, Campfires, Picnic Tables & Pines)
--------------------------------------------------------------------------------
local function buildMapCampingPark(structureFolder: Folder): { { Build: () -> Model, Pos: Vector3, Yaw: number } }
	buildArenaShell(
		structureFolder,
		Color3.fromRGB(68, 128, 64),
		Enum.Material.Grass,
		Color3.fromRGB(112, 84, 58),
		Color3.fromRGB(82, 58, 38),
		Color3.fromRGB(255, 195, 115)
	)

	-- Cobblestone Crosswalk Paths & Central Campfire Plaza across 240x240
	part({ Name = "StonePathNS", Size = Vector3.new(18, 0.1, MAP_SIZE - 8), Position = Vector3.new(0, 0.05, 0), Color = Color3.fromRGB(135, 132, 125), Material = Enum.Material.Cobblestone, Parent = structureFolder })
	part({ Name = "StonePathEW", Size = Vector3.new(MAP_SIZE - 8, 0.1, 18), Position = Vector3.new(0, 0.05, 0), Color = Color3.fromRGB(135, 132, 125), Material = Enum.Material.Cobblestone, Parent = structureFolder })
	part({ Name = "CenterStoneCircle", Size = Vector3.new(52, 0.12, 52), Position = Vector3.new(0, 0.06, 0), Color = Color3.fromRGB(145, 140, 132), Material = Enum.Material.Cobblestone, Parent = structureFolder })

	-- Wooden Ranger Fence / Cabin Dividers
	for i, fw in {
		{ Size = Vector3.new(48, 9, 1.5), Pos = Vector3.new(64, 4.5, -22) },
		{ Size = Vector3.new(1.5, 9, 48), Pos = Vector3.new(-22, 4.5, 64) },
		{ Size = Vector3.new(48, 9, 1.5), Pos = Vector3.new(-64, 4.5, -22) },
		{ Size = Vector3.new(1.5, 9, 48), Pos = Vector3.new(22, 4.5, 64) },
	} do
		part({ Name = "TimberWall_" .. i, Size = fw.Size, Position = fw.Pos, Color = Color3.fromRGB(122, 82, 48), Material = Enum.Material.WoodPlanks, Parent = structureFolder })
	end

	local orangeTent = function() return createCampingTentModel(Color3.fromRGB(230, 125, 45)) end
	local greenTent = function() return createCampingTentModel(Color3.fromRGB(65, 155, 85)) end
	local blueTent = function() return createCampingTentModel(Color3.fromRGB(55, 135, 215)) end
	local redTent = function() return createCampingTentModel(Color3.fromRGB(205, 65, 65)) end
	local greenBarrel = function() return createBarrelModel(Color3.fromRGB(55, 135, 72), Color3.fromRGB(220, 195, 135)) end

	local baseProps = {
		{ Build = createCampfireModel, Pos = Vector3.new(0, 0, -8), Yaw = 0 },
		{ Build = createPicnicTableModel, Pos = Vector3.new(-10, 0, 0), Yaw = 90 },
		{ Build = createPicnicTableModel, Pos = Vector3.new(10, 0, 0), Yaw = 90 },

		{ Build = orangeTent, Pos = Vector3.new(26, 0, -44), Yaw = 25 },
		{ Build = greenTent, Pos = Vector3.new(44, 0, -42), Yaw = -20 },
		{ Build = blueTent, Pos = Vector3.new(46, 0, -24), Yaw = 110 },
		{ Build = createCampfireModel, Pos = Vector3.new(34, 0, -32), Yaw = 0 },
		{ Build = createPicnicTableModel, Pos = Vector3.new(24, 0, -24), Yaw = 0 },
		{ Build = createPineTreeModel, Pos = Vector3.new(52, 0, -52), Yaw = 0 },
		{ Build = createPineTreeModel, Pos = Vector3.new(16, 0, -52), Yaw = 15 },
		{ Build = createCrateModel, Pos = Vector3.new(50, 0, -16), Yaw = 0 },

		{ Build = createPineTreeModel, Pos = Vector3.new(-50, 0, -50), Yaw = 0 },
		{ Build = createPineTreeModel, Pos = Vector3.new(-36, 0, -52), Yaw = 30 },
		{ Build = createPineTreeModel, Pos = Vector3.new(-52, 0, -34), Yaw = 45 },
		{ Build = createPineTreeModel, Pos = Vector3.new(-22, 0, -46), Yaw = 10 },
		{ Build = redTent, Pos = Vector3.new(-38, 0, -36), Yaw = -35 },
		{ Build = createCampfireModel, Pos = Vector3.new(-30, 0, -28), Yaw = 0 },
		{ Build = createCrateModel, Pos = Vector3.new(-48, 0, -20), Yaw = 0 },
		{ Build = createPalletStackModel, Pos = Vector3.new(-42, 0, -20), Yaw = 15 },
		{ Build = greenBarrel, Pos = Vector3.new(-20, 0, -24), Yaw = 0 },

		{ Build = createPicnicTableModel, Pos = Vector3.new(-42, 0, 26), Yaw = 0 },
		{ Build = createPicnicTableModel, Pos = Vector3.new(-26, 0, 26), Yaw = 0 },
		{ Build = createPicnicTableModel, Pos = Vector3.new(-42, 0, 44), Yaw = 0 },
		{ Build = createPicnicTableModel, Pos = Vector3.new(-26, 0, 44), Yaw = 0 },
		{ Build = createTrashBinModel, Pos = Vector3.new(-16, 0, 22), Yaw = 0 },
		{ Build = createTrashBinModel, Pos = Vector3.new(-52, 0, 35), Yaw = 0 },
		{ Build = createPineTreeModel, Pos = Vector3.new(-52, 0, 52), Yaw = 0 },
		{ Build = createPlantPotModel, Pos = Vector3.new(-18, 0, 50), Yaw = 0 },
		{ Build = createFloorLampModel, Pos = Vector3.new(-34, 0, 35), Yaw = 0 },

		{ Build = blueTent, Pos = Vector3.new(28, 0, 46), Yaw = -15 },
		{ Build = orangeTent, Pos = Vector3.new(46, 0, 42), Yaw = 40 },
		{ Build = greenTent, Pos = Vector3.new(44, 0, 24), Yaw = -60 },
		{ Build = createCampfireModel, Pos = Vector3.new(34, 0, 32), Yaw = 0 },
		{ Build = createPineTreeModel, Pos = Vector3.new(52, 0, 52), Yaw = 0 },
		{ Build = createPineTreeModel, Pos = Vector3.new(20, 0, 52), Yaw = 20 },
		{ Build = greenBarrel, Pos = Vector3.new(22, 0, 22), Yaw = 0 },
		{ Build = createCrateModel, Pos = Vector3.new(26, 0, 22), Yaw = 12 },
		{ Build = createTrafficConeModel, Pos = Vector3.new(16, 0, 16), Yaw = 0 },
	}

	local extraOuter = {
		{ Build = createPineTreeModel, Pos = Vector3.new(104, 0, -104), Yaw = 0 },
		{ Build = createPineTreeModel, Pos = Vector3.new(-104, 0, -104), Yaw = 25 },
		{ Build = createPineTreeModel, Pos = Vector3.new(-104, 0, 104), Yaw = 15 },
		{ Build = createPineTreeModel, Pos = Vector3.new(104, 0, 104), Yaw = 40 },
		{ Build = createPineTreeModel, Pos = Vector3.new(72, 0, -102), Yaw = 10 },
		{ Build = createPineTreeModel, Pos = Vector3.new(-72, 0, 102), Yaw = 20 },
		{ Build = orangeTent, Pos = Vector3.new(-82, 0, -56), Yaw = 35 },
		{ Build = greenTent, Pos = Vector3.new(92, 0, -68), Yaw = -45 },
		{ Build = redTent, Pos = Vector3.new(92, 0, 68), Yaw = 120 },
		{ Build = createPicnicTableModel, Pos = Vector3.new(68, 0, 48), Yaw = 0 },
		{ Build = createCampfireModel, Pos = Vector3.new(-68, 0, 62), Yaw = 0 },
	}

	return scaleAndMergePlacements(baseProps, extraOuter)
end

--------------------------------------------------------------------------------
-- MAIN MAP GENERATOR ENTRY POINT
--------------------------------------------------------------------------------
function MapBuilder.Generate(mapId: string?)
	local chosenId: string = mapId or "GrandPlaza"

	-- Find or create top-level GameMap folder
	local mapFolder = workspace:FindFirstChild("GameMap") :: Folder?
	if not mapFolder then
		mapFolder = Instance.new("Folder")
		mapFolder.Name = "GameMap"
		mapFolder.Parent = workspace
	end

	-- Clean up only the Arena Structure & Props so SkyLoungeLobby stays intact!
	for _, childName in { "Structure", "Props" } do
		local old = mapFolder:FindFirstChild(childName)
		if old then
			old:Destroy()
		end
	end

	-- Ensure permanent Sky Lounge Lobby, MapSpawns, and SeekerWaitingBox exist
	ensureSkyLoungeLobby(mapFolder)

	if not workspace:FindFirstChild("MapSpawn") then
		part({
			Name = "MapSpawn",
			Size = Vector3.new(10, 0.2, 10),
			Position = Vector3.new(0, FLOOR_Y + 0.1, 0),
			Color = Color3.fromRGB(80, 175, 255),
			Transparency = 0.6,
			CanCollide = false,
			Material = Enum.Material.SmoothPlastic,
			Parent = workspace,
		})
	end

	-- Create 8 distributed MapSpawns across the spacious 240x240 arena
	if not workspace:FindFirstChild("MapSpawns") then
		local spawnsFolder = Instance.new("Folder")
		spawnsFolder.Name = "MapSpawns"
		spawnsFolder.Parent = workspace
		for idx, spPos in {
			Vector3.new(0, FLOOR_Y + 0.2, 0),
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
				Parent = spawnsFolder,
			})
		end
	end

	local seekerBox = workspace:FindFirstChild("SeekerWaitingBox") :: BasePart?
	if not seekerBox then
		part({
			Name = "SeekerWaitingBox",
			Size = Vector3.new(18, 1, 18),
			Position = Vector3.new(180, WALL_HEIGHT + 12, 0),
			Color = Color3.fromRGB(220, 65, 65),
			Material = Enum.Material.Metal,
			Parent = workspace,
		})
	else
		seekerBox.Position = Vector3.new(180, WALL_HEIGHT + 12, 0)
	end

	local structureFolder = Instance.new("Folder")
	structureFolder.Name = "Structure"
	structureFolder.Parent = mapFolder

	local propsFolder = Instance.new("Folder")
	propsFolder.Name = "Props"
	propsFolder.Parent = mapFolder

	-- 4 Central Atrium Columns (shared across maps to support the 48x48 Skylight)
	for _, sx in { -23, 23 } do
		for _, sz in { -23, 23 } do
			part({
				Name = "AtriumPillar",
				Size = Vector3.new(3.4, WALL_HEIGHT, 3.4),
				Position = Vector3.new(sx, WALL_HEIGHT / 2, sz),
				Color = Color3.fromRGB(48, 52, 62),
				Material = Enum.Material.Metal,
				Parent = structureFolder,
			})
		end
	end

	-- Configure eye-friendly Lighting & Bloom (prevents blinding white/yellow glare)
	Lighting.ExposureCompensation = -0.15
	Lighting.EnvironmentDiffuseScale = 0.4
	Lighting.EnvironmentSpecularScale = 0.3
	Lighting.OutdoorAmbient = Color3.fromRGB(85, 90, 100)

	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	if not bloom then
		bloom = Instance.new("BloomEffect")
		bloom.Name = "Bloom"
		bloom.Parent = Lighting
	end
	bloom.Enabled = true
	bloom.Intensity = 0.22
	bloom.Threshold = 2.8
	bloom.Size = 16

	local sunRays = Lighting:FindFirstChildOfClass("SunRaysEffect")
	if sunRays then
		sunRays.Intensity = 0.04
	end

	-- Build the selected map's Arena & Prop Placements
	local placements: { { Build: () -> Model, Pos: Vector3, Yaw: number } }
	if chosenId == "CyberpunkMall" then
		Lighting.Brightness = 1.05
		Lighting.Ambient = Color3.fromRGB(55, 48, 82)
		placements = buildMapCyberpunkMall(structureFolder)
	elseif chosenId == "SchoolCampus" then
		Lighting.Brightness = 1.2
		Lighting.Ambient = Color3.fromRGB(82, 80, 76)
		placements = buildMapSchoolCampus(structureFolder)
	elseif chosenId == "CampingPark" then
		Lighting.Brightness = 1.15
		Lighting.Ambient = Color3.fromRGB(80, 72, 65)
		placements = buildMapCampingPark(structureFolder)
	else
		chosenId = "GrandPlaza"
		Lighting.Brightness = 1.2
		Lighting.Ambient = Color3.fromRGB(78, 82, 95)
		placements = buildMapGrandPlaza(structureFolder)
	end

	for index, item in placements do
		local propModel = item.Build()
		propModel.Name = string.format("%s_%02d", propModel.Name, index)
		placeMorphableProp(propModel, propsFolder, item.Pos, item.Yaw)
	end

	workspace:SetAttribute("ActiveMapId", chosenId)
	print(string.format("[MapBuilder] Built Map '%s' with %d 'Morphable' props!", chosenId, #placements))
end

return MapBuilder
