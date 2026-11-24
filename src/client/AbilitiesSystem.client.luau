--!strict
-- StarterPlayerScripts/Client/AbilitiesSystem.client.luau
-- Client input and sleek glassmorphic toast notifications for Hider & Seeker Abilities

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local Teams = game:GetService("Teams")
local TweenService = game:GetService("TweenService")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui

local PropRemotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PropRemotes"))
local MobileActionBus = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MobileActionBus"))
local abilityRequestEvent = PropRemotes.AbilityRequest
local radarFeedbackEvent = PropRemotes.RadarFeedback
local roundEventNotice = PropRemotes.RoundEventNotice

local existingToast = playerGui:FindFirstChild("PropHuntAbilitiesGui")
if existingToast then
	existingToast:Destroy()
end

local toastGui = Instance.new("ScreenGui")
toastGui.Name = "PropHuntAbilitiesGui"
toastGui.ResetOnSpawn = false
toastGui.IgnoreGuiInset = true
toastGui.Parent = playerGui

local radarToast = Instance.new("TextLabel")
radarToast.Name = "RadarToast"
radarToast.Size = UDim2.fromOffset(410, 44)
radarToast.Position = UDim2.new(0.5, 0, 0, 92)
radarToast.AnchorPoint = Vector2.new(0.5, 0)
radarToast.BackgroundColor3 = Color3.fromRGB(16, 20, 32)
radarToast.BackgroundTransparency = 1
radarToast.TextTransparency = 1
radarToast.Font = Enum.Font.GothamBlack
radarToast.TextSize = 15
radarToast.TextColor3 = Color3.fromRGB(255, 220, 85)
radarToast.Text = ""
radarToast.ZIndex = 32
radarToast.Parent = toastGui

local toastCorner = Instance.new("UICorner")
toastCorner.CornerRadius = UDim.new(0, 12)
toastCorner.Parent = radarToast

local toastStroke = Instance.new("UIStroke")
toastStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
toastStroke.Color = Color3.fromRGB(255, 205, 70)
toastStroke.Thickness = 1.6
toastStroke.Transparency = 1
toastStroke.Parent = radarToast

local toastScale = Instance.new("UIScale")
toastScale.Parent = radarToast

local function updateToastResponsive()
	local isPhone = MobileActionBus.IsCompactPhone()
	toastScale.Scale = if isPhone then 0.76 else 1.0
	radarToast.Position = if isPhone then UDim2.new(0.5, 0, 0, 68) else UDim2.new(0.5, 0, 0, 92)
end
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateToastResponsive)
	updateToastResponsive()
end

local function showToastMessage(text: string, color: Color3)
	radarToast.Text = text
	radarToast.TextColor3 = color
	toastStroke.Color = color
	radarToast.BackgroundTransparency = 0.08
	radarToast.TextTransparency = 0
	toastStroke.Transparency = 0.2

	task.delay(3.0, function()
		if radarToast.Text == text then
			TweenService:Create(radarToast, TweenInfo.new(0.4), {
				BackgroundTransparency = 1,
				TextTransparency = 1,
			}):Play()
			TweenService:Create(toastStroke, TweenInfo.new(0.4), {
				Transparency = 1,
			}):Play()
		end
	end)
end

radarFeedbackEvent.OnClientEvent:Connect(function(message: string, distance: number)
	local color = if distance <= 22
		then Color3.fromRGB(255, 90, 95)
		elseif distance <= 50 then Color3.fromRGB(255, 205, 70)
		else Color3.fromRGB(95, 200, 255)

	showToastMessage("📡 " .. message, color)
end)

roundEventNotice.OnClientEvent:Connect(function(eventType: string, payload: { [string]: any }?)
	if eventType == "AbilityError" and typeof(payload) == "table" then
		showToastMessage(tostring(payload.Message or "ไม่สามารถใช้สกิลได้"), Color3.fromRGB(255, 115, 95))
	elseif eventType == "QuestComplete" and typeof(payload) == "table" then
		showToastMessage("🎉 " .. tostring(payload.Title or "ภารกิจสำเร็จ!"), Color3.fromRGB(95, 255, 140))
	elseif eventType == "HiderHintWarning" and typeof(payload) == "table" then
		showToastMessage(tostring(payload.Message or "⚠️ เหลือ 30 วิสุดท้าย!"), Color3.fromRGB(255, 205, 75))
	end
end)

local function isHider(): boolean
	local hidersTeam = Teams:FindFirstChild("Hiders")
	return hidersTeam ~= nil and localPlayer.Team == hidersTeam
end

local function isSeeker(): boolean
	local seekersTeam = Teams:FindFirstChild("Seekers")
	return seekersTeam ~= nil and localPlayer.Team == seekersTeam
end

-- Bind PC keys only (false = no overlapping default ContextActionService grey touch buttons!)
ContextActionService:BindAction("HiderSpawnDecoy", function(_name, state, _input)
	if state ~= Enum.UserInputState.Begin or not isHider() then
		return Enum.ContextActionResult.Pass
	end
	abilityRequestEvent:FireServer("SpawnDecoy")
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.G)

ContextActionService:BindAction("HiderSmokeSprint", function(_name, state, _input)
	if state ~= Enum.UserInputState.Begin or not isHider() then
		return Enum.ContextActionResult.Pass
	end
	abilityRequestEvent:FireServer("SmokeSprint")
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.LeftShift)

ContextActionService:BindAction("SeekerSonarRadar", function(_name, state, _input)
	if state ~= Enum.UserInputState.Begin or not isSeeker() then
		return Enum.ContextActionResult.Pass
	end
	abilityRequestEvent:FireServer("SeekerRadar")
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.Q)

ContextActionService:BindAction("SeekerSpeedSurge", function(_name, state, _input)
	if state ~= Enum.UserInputState.Begin or not isSeeker() then
		return Enum.ContextActionResult.Pass
	end
	abilityRequestEvent:FireServer("SeekerSurge")
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.E)

MobileActionBus.Connect(function(action)
	if action == "SpawnDecoy" and isHider() then
		abilityRequestEvent:FireServer("SpawnDecoy")
	elseif action == "SmokeSprint" and isHider() then
		abilityRequestEvent:FireServer("SmokeSprint")
	elseif action == "SeekerRadar" and isSeeker() then
		abilityRequestEvent:FireServer("SeekerRadar")
	elseif action == "SeekerSurge" and isSeeker() then
		abilityRequestEvent:FireServer("SeekerSurge")
	end
end)
ContextActionService:SetPosition("SeekerSpeedSurge", UDim2.new(0.84, 0, 0.42, 0))
