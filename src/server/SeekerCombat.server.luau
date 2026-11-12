--!strict
-- ServerScriptService/Server/SeekerCombat.server.luau
-- Handles Seeker attacks (Case A: 50 dmg + highlight to Hiders, Case B: 15 self-damage on real Morphable props, Case C: nothing on walls/floors).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Teams = game:GetService("Teams")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local PropRemotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PropRemotes"))
local seekerAttackEvent = PropRemotes.SeekerAttackRequest
local roundEventNotice = PropRemotes.RoundEventNotice

-- Combat Constants
local MAX_ATTACK_DISTANCE = 10 -- 10 studs max range
local ATTACK_COOLDOWN = 1.0 -- 1-second server cooldown
local HIDER_HIT_DAMAGE = 50 -- Case A: Damage dealt to a Hider
local SEEKER_MISS_PENALTY = 15 -- Case B: Health penalty when hitting a real Morphable object

local MORPH_TAG = "Morphable"
local SEEKERS_TEAM_NAME = "Seekers"
local HIDERS_TEAM_NAME = "Hiders"

local lastAttackTime: { [Player]: number } = {}

-- Helper: Verify the player is on the Seekers team and alive
local function getValidSeeker(player: Player): (boolean, Model?, BasePart?, Humanoid?)
	local seekersTeam = Teams:FindFirstChild(SEEKERS_TEAM_NAME)
	if seekersTeam and player.Team ~= seekersTeam then
		return false, nil, nil, nil
	end

	local character = player.Character
	if not character then
		return false, nil, nil, nil
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not rootPart or not humanoid or humanoid.Health <= 0 then
		return false, nil, nil, nil
	end

	return true, character, rootPart, humanoid
end

-- Helper (Case A Check): Resolve if hitInstance belongs to a Hider or their attached prop
local function getHiderFromHit(hitInstance: Instance): (Player?, Model?, Humanoid?, BasePart?)
	local hidersTeam = Teams:FindFirstChild(HIDERS_TEAM_NAME)
	local current: Instance? = hitInstance

	while current and current ~= workspace do
		if current:IsA("Model") then
			local hitPlayer = Players:GetPlayerFromCharacter(current)
			if hitPlayer then
				if not hidersTeam or hitPlayer.Team == hidersTeam then
					local humanoid = current:FindFirstChildOfClass("Humanoid")
					local rootPart = current:FindFirstChild("HumanoidRootPart") :: BasePart?
					if humanoid and humanoid.Health > 0 and rootPart then
						return hitPlayer, current, humanoid, rootPart
					end
				end
			end
		end
		current = current.Parent
	end

	return nil, nil, nil, nil
end

-- Helper (Case B Check): Check if hitInstance is a real "Morphable" object in Workspace (not a player)
local function isRealMorphableProp(hitInstance: Instance): boolean
	local current: Instance? = hitInstance
	while current and current ~= workspace do
		if current:IsA("Model") and Players:GetPlayerFromCharacter(current) then
			return false
		end

		if CollectionService:HasTag(current, MORPH_TAG) then
			return true
		end
		current = current.Parent
	end
	return false
end

-- Helper: Play a brief hit Highlight effect on the Hider or their attached prop
local function playHitHighlightEffect(hiderCharacter: Model)
	local targetAdornee = hiderCharacter:FindFirstChild("MorphedProp") or hiderCharacter

	local highlight = Instance.new("Highlight")
	highlight.Name = "SeekerHitHighlight"
	highlight.Adornee = targetAdornee
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.FillColor = Color3.fromRGB(255, 60, 60)
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	highlight.FillTransparency = 0.2
	highlight.OutlineTransparency = 0
	highlight.Parent = targetAdornee

	local fadeOut = TweenService:Create(
		highlight,
		TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ FillTransparency = 1, OutlineTransparency = 1 }
	)
	fadeOut:Play()
	Debris:AddItem(highlight, 0.55)
end

-- Handle Seeker Attack Request
seekerAttackEvent.OnServerEvent:Connect(function(seeker: Player, aimOrigin: Vector3, aimDirection: Vector3)
	if typeof(aimOrigin) ~= "Vector3" or typeof(aimDirection) ~= "Vector3" then
		return
	end

	-- 1-second server cooldown
	local now = os.clock()
	if lastAttackTime[seeker] and (now - lastAttackTime[seeker]) < ATTACK_COOLDOWN then
		return
	end

	local isSeeker, seekerChar, seekerRoot, seekerHumanoid = getValidSeeker(seeker)
	if not isSeeker or not seekerChar or not seekerRoot or not seekerHumanoid then
		return
	end

	if (aimOrigin - seekerRoot.Position).Magnitude > 25 then
		return
	end

	lastAttackTime[seeker] = now

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { seekerChar }

	local unitDir = aimDirection.Unit
	local cameraToRootDist = (aimOrigin - seekerRoot.Position).Magnitude
	local maxRayLength = cameraToRootDist + MAX_ATTACK_DISTANCE + 2

	local rayResult = workspace:Raycast(aimOrigin, unitDir * maxRayLength, rayParams)
	if not rayResult or not rayResult.Instance then
		return
	end

	local hitInstance = rayResult.Instance
	local hitPosition = rayResult.Position

	-- Validate 10-stud reach from character
	if (seekerRoot.Position - hitPosition).Magnitude > MAX_ATTACK_DISTANCE then
		return
	end

	-- Case A: Hits a Hider or their attached Prop -> 50 damage + Highlight effect
	local hiderPlayer, hiderChar, hiderHumanoid, hiderRoot = getHiderFromHit(hitInstance)
	if hiderChar and hiderHumanoid and hiderRoot then
		if hiderRoot.Anchored then
			hiderRoot.Anchored = false
			hiderHumanoid.AutoRotate = true
			hiderChar:SetAttribute("IsPropLocked", false)
		end

		local propName = tostring(hiderChar:GetAttribute("MorphedPropName") or "Prop")
		local prevHealth = hiderHumanoid.Health
		hiderHumanoid:TakeDamage(HIDER_HIT_DAMAGE)
		playHitHighlightEffect(hiderChar)

		if prevHealth > 0 and hiderHumanoid.Health <= 0 and hiderPlayer then
			roundEventNotice:FireAllClients("KillFeed", {
				Killer = seeker.DisplayName,
				Victim = hiderPlayer.DisplayName,
				PropName = propName,
				Reason = "Eliminated",
			})
		end
		return
	end

	-- Case B: Hits a real "Morphable" object in Workspace -> Deduct 15 health from Seeker
	if isRealMorphableProp(hitInstance) then
		local prevHealth = seekerHumanoid.Health
		seekerHumanoid:TakeDamage(SEEKER_MISS_PENALTY)
		if prevHealth > 0 and seekerHumanoid.Health <= 0 then
			roundEventNotice:FireAllClients("KillFeed", {
				Killer = "Prop Penalty",
				Victim = seeker.DisplayName,
				PropName = hitInstance.Name,
				Reason = "SelfEliminated",
			})
		end
		return
	end

	-- Case C: Hits regular walls/floors -> Do nothing
end)

Players.PlayerRemoving:Connect(function(player: Player)
	lastAttackTime[player] = nil
end)
