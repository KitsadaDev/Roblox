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

-- ContextActionService Handler (T Key + Mobile Touch Button)
local function handleTauntAction(_actionName: string, inputState: Enum.UserInputState, _inputObject: InputObject)
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end

	if not canLocalPlayerTaunt() then
		return Enum.ContextActionResult.Pass
	end

	local now = os.clock()
	if (now - lastClientTaunt) < MANUAL_TAUNT_COOLDOWN then
		return Enum.ContextActionResult.Sink
	end

	lastClientTaunt = now
	tauntRequestEvent:FireServer()
	return Enum.ContextActionResult.Sink
end

-- Bind "T" key and create mobile button
ContextActionService:BindAction(ACTION_NAME, handleTauntAction, true, Enum.KeyCode.T)
ContextActionService:SetTitle(ACTION_NAME, "Taunt (+10)")
ContextActionService:SetPosition(ACTION_NAME, UDim2.new(0.72, 0, 0.42, 0))

