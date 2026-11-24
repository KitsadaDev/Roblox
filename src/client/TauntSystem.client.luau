--!strict
-- StarterPlayerScripts/Client/TauntSystem.client.luau
-- Client-side Manual Taunt input handler:
-- Binds the "T" key and a ContextActionService mobile button for Hiders during the Hunting Phase.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local Teams = game:GetService("Teams")

local localPlayer = Players.LocalPlayer

local PropRemotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PropRemotes"))
local MobileActionBus = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MobileActionBus"))
local tauntRequestEvent = PropRemotes.TauntRequest

local MANUAL_TAUNT_COOLDOWN = 10.0
local HIDERS_TEAM_NAME = "Hiders"
local ACTION_NAME = "HiderManualTaunt"

local lastClientTaunt = 0

-- Helper: Check if the local player is an alive Hider during the Hunting Phase
local function canLocalPlayerTaunt(): boolean
	if workspace:GetAttribute("RoundState") ~= "HuntingPhase" then
		return false
	end

	local hidersTeam = Teams:FindFirstChild(HIDERS_TEAM_NAME)
	if hidersTeam and localPlayer.Team ~= hidersTeam then
		return false
	end

	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false
	end

	return true
end

local function tryPerformTaunt(): boolean
	if not canLocalPlayerTaunt() then
		return false
	end

	local now = os.clock()
	if (now - lastClientTaunt) < MANUAL_TAUNT_COOLDOWN then
		return true
	end

	lastClientTaunt = now
	tauntRequestEvent:FireServer()
	return true
end

-- ContextActionService Handler (T Key on PC)
local function handleTauntAction(_actionName: string, inputState: Enum.UserInputState, _inputObject: InputObject)
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end

	if tryPerformTaunt() then
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end

-- Bind "T" key only (custom mobile button triggers via MobileActionBus)
ContextActionService:BindAction(ACTION_NAME, handleTauntAction, false, Enum.KeyCode.T)

MobileActionBus.Connect(function(action)
	if action == "Taunt" then
		tryPerformTaunt()
	end
end)

