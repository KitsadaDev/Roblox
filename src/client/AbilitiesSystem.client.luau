--!strict
-- StarterPlayerScripts/Client/AbilitiesSystem.client.luau
-- Client input and toast notifications for Hider & Seeker Abilities:
-- - Hiders: [G] Spawn Decoy (20 Coins), [LeftShift] Smoke Sprint (18s CD)
-- - Seekers: [Q] Sonar Radar Scan (15s CD) + On-screen Radar readout

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

-- Create a sleek Toast Notification label for Seeker Radar & Ability feedback
local toastGui = Instance.new("ScreenGui")
toastGui.Name = "PropHuntAbilitiesGui"
toastGui.ResetOnSpawn = false
toastGui.Parent = playerGui

local radarToast = Instance.new("TextLabel")
radarToast.Name = "RadarToast"
radarToast.Size = UDim2.new(0, 380, 0, 42)
radarToast.Position = UDim2.new(0.5, 0, 0, 96)
radarToast.AnchorPoint = Vector2.new(0.5, 0)
radarToast.BackgroundColor3 = Color3.fromRGB(22, 24, 34)
radarToast.BackgroundTransparency = 1
radarToast.TextTransparency = 1
radarToast.Font = Enum.Font.GothamBlack
radarToast.TextSize = 16
radarToast.TextColor3 = Color3.fromRGB(255, 215, 80)
radarToast.Text = ""
radarToast.Parent = toastGui

local toastCorner = Instance.new("UICorner")
toastCorner.CornerRadius = UDim.new(0, 10)
toastCorner.Parent = radarToast

local function showToastMessage(text: string, color: Color3)
	radarToast.Text = text
	radarToast.TextColor3 = color
	radarToast.BackgroundTransparency = 0.15
	radarToast.TextTransparency = 0

	task.delay(3.0, function()
		if radarToast.Text == text then
			TweenService:Create(radarToast, TweenInfo.new(0.4), {
				BackgroundTransparency = 1,
				TextTransparency = 1,
			}):Play()
		end
	end)
end

radarFeedbackEvent.OnClientEvent:Connect(function(message: string, distance: number)
	local color = if distance <= 22
		then Color3.fromRGB(255, 85, 85)
		elseif distance <= 50 then Color3.fromRGB(255, 200, 65)
		else Color3.fromRGB(110, 195, 255)

	showToastMessage(message, color)
end)

roundEventNotice.OnClientEvent:Connect(function(eventType: string, payload: { [string]: any }?)
	if eventType == "AbilityError" and typeof(payload) == "table" then
		showToastMessage(tostring(payload.Message or "ไม่สามารถใช้สกิลได้"), Color3.fromRGB(255, 115, 95))
	elseif eventType == "QuestComplete" and typeof(payload) == "table" then
		showToastMessage("🎉 " .. tostring(payload.Title or "ภารกิจสำเร็จ!"), Color3.fromRGB(95, 255, 135))
	end
end)

-- Input Handlers
local function isHider(): boolean
	local hidersTeam = Teams:FindFirstChild("Hiders")
	return hidersTeam ~= nil and localPlayer.Team == hidersTeam
end

local function isSeeker(): boolean
	local seekersTeam = Teams:FindFirstChild("Seekers")
	return seekersTeam ~= nil and localPlayer.Team == seekersTeam
end

-- [G] Hider Decoy Clone (20 Coins) — Mobile button enabled!
ContextActionService:BindAction("HiderSpawnDecoy", function(_name, state, _input)
	if state ~= Enum.UserInputState.Begin or not isHider() then
		return Enum.ContextActionResult.Pass
	end
	abilityRequestEvent:FireServer("SpawnDecoy")
	return Enum.ContextActionResult.Sink
end, true, Enum.KeyCode.G)
ContextActionService:SetTitle("HiderSpawnDecoy", "Decoy [G]")
ContextActionService:SetPosition("HiderSpawnDecoy", UDim2.new(0.60, 0, 0.42, 0))

-- [LeftShift] Hider Smoke Sprint — Mobile button enabled!
ContextActionService:BindAction("HiderSmokeSprint", function(_name, state, _input)
	if state ~= Enum.UserInputState.Begin or not isHider() then
		return Enum.ContextActionResult.Pass
	end
	abilityRequestEvent:FireServer("SmokeSprint")
	return Enum.ContextActionResult.Sink
end, true, Enum.KeyCode.LeftShift)
ContextActionService:SetTitle("HiderSmokeSprint", "Sprint")
ContextActionService:SetPosition("HiderSmokeSprint", UDim2.new(0.84, 0, 0.42, 0))

-- [Q] Seeker Sonar Radar
ContextActionService:BindAction("SeekerSonarRadar", function(_name, state, _input)
	if state ~= Enum.UserInputState.Begin or not isSeeker() then
		return Enum.ContextActionResult.Pass
	end
	abilityRequestEvent:FireServer("SeekerRadar")
	return Enum.ContextActionResult.Sink
end, true, Enum.KeyCode.Q)
ContextActionService:SetTitle("SeekerSonarRadar", "Radar [Q]")
ContextActionService:SetPosition("SeekerSonarRadar", UDim2.new(0.72, 0, 0.42, 0))

-- [E] Seeker Speed Surge (20s CD, 4s Speed 24)
ContextActionService:BindAction("SeekerSpeedSurge", function(_name, state, _input)
	if state ~= Enum.UserInputState.Begin or not isSeeker() then
		return Enum.ContextActionResult.Pass
	end
	abilityRequestEvent:FireServer("SeekerSurge")
	return Enum.ContextActionResult.Sink
end, true, Enum.KeyCode.E)
ContextActionService:SetTitle("SeekerSpeedSurge", "Surge [E]")
ContextActionService:SetPosition("SeekerSpeedSurge", UDim2.new(0.84, 0, 0.42, 0))

