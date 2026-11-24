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

ContextActionService:BindAction("HiderSpawnDecoy", function(_name, state, _input)
	if state ~= Enum.UserInputState.Begin or not isHider() then
		return Enum.ContextActionResult.Pass
	end
	abilityRequestEvent:FireServer("SpawnDecoy")
	return Enum.ContextActionResult.Sink
end, true, Enum.KeyCode.G)
ContextActionService:SetTitle("HiderSpawnDecoy", "Decoy [G]")
ContextActionService:SetPosition("HiderSpawnDecoy", UDim2.new(0.60, 0, 0.42, 0))

ContextActionService:BindAction("HiderSmokeSprint", function(_name, state, _input)
	if state ~= Enum.UserInputState.Begin or not isHider() then
		return Enum.ContextActionResult.Pass
	end
	abilityRequestEvent:FireServer("SmokeSprint")
	return Enum.ContextActionResult.Sink
end, true, Enum.KeyCode.LeftShift)
ContextActionService:SetTitle("HiderSmokeSprint", "Sprint")
ContextActionService:SetPosition("HiderSmokeSprint", UDim2.new(0.84, 0, 0.42, 0))

ContextActionService:BindAction("SeekerSonarRadar", function(_name, state, _input)
	if state ~= Enum.UserInputState.Begin or not isSeeker() then
		return Enum.ContextActionResult.Pass
	end
	abilityRequestEvent:FireServer("SeekerRadar")
	return Enum.ContextActionResult.Sink
end, true, Enum.KeyCode.Q)
ContextActionService:SetTitle("SeekerSonarRadar", "Radar [Q]")
ContextActionService:SetPosition("SeekerSonarRadar", UDim2.new(0.72, 0, 0.42, 0))

ContextActionService:BindAction("SeekerSpeedSurge", function(_name, state, _input)
	if state ~= Enum.UserInputState.Begin or not isSeeker() then
		return Enum.ContextActionResult.Pass
	end
	abilityRequestEvent:FireServer("SeekerSurge")
	return Enum.ContextActionResult.Sink
end, true, Enum.KeyCode.E)
ContextActionService:SetTitle("SeekerSpeedSurge", "Surge [E]")
ContextActionService:SetPosition("SeekerSpeedSurge", UDim2.new(0.84, 0, 0.42, 0))
