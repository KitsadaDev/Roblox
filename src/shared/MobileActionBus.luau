--!strict
-- ReplicatedStorage/Shared/MobileActionBus.luau
-- Client-side BindableEvent bus & responsive mobile/touch detection helpers
-- used to connect custom mobile HUD touch buttons to gameplay client scripts.

local UserInputService = game:GetService("UserInputService")

local actionEvent = Instance.new("BindableEvent")
actionEvent.Name = "MobileActionBusEvent"

local MobileActionBus = {}

export type MobileActionName =
	"Morph"
	| "ToggleLock"
	| "RotateProp"
	| "Taunt"
	| "SpawnDecoy"
	| "SmokeSprint"
	| "SeekerShoot"
	| "SeekerRadar"
	| "SeekerSurge"

function MobileActionBus.Fire(action: MobileActionName)
	actionEvent:Fire(action)
end

function MobileActionBus.Connect(callback: (action: MobileActionName) -> ()): RBXScriptConnection
	return actionEvent.Event:Connect(callback)
end

-- True when the player is on a touch device without a physical keyboard (Phone / Tablet / Studio Touch Emulator)
function MobileActionBus.UseTouchControls(): boolean
	local cam = workspace.CurrentCamera
	local vp = if cam then cam.ViewportSize else Vector2.new(1280, 720)
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return true
	end
	return vp.Y > 0 and vp.Y < 500 and UserInputService.TouchEnabled
end

-- True when the viewport height/width corresponds to a compact mobile phone screen
function MobileActionBus.IsCompactPhone(): boolean
	local cam = workspace.CurrentCamera
	local vp = if cam then cam.ViewportSize else Vector2.new(1280, 720)
	return vp.Y > 0 and (vp.Y < 540 or vp.X < 900)
end

return MobileActionBus
