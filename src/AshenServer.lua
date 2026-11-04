-- Ashen Realm server. Builds the map on play, then runs the throne war.
-- Map, combat, banners, the Cinder Seat, dragonfire, and Ash Marauders.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local Teams = game:GetService("Teams")
local Debris = game:GetService("Debris")
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("AshenConfig"))

Players.CharacterAutoLoads = false
Players.RespawnTime = Config.RespawnTime

local remotesFolder = ReplicatedStorage:FindFirstChild("AshenRemotes")
if remotesFolder then
	remotesFolder:Destroy()
end
remotesFolder = Instance.new("Folder")
remotesFolder.Name = "AshenRemotes"
remotesFolder.Parent = ReplicatedStorage

local function makeRemote(name)
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotesFolder
	return remote
end

local ChooseHouse = makeRemote("ChooseHouse")
local Swing = makeRemote("Swing")
local Block = makeRemote("Block")
local Toast = makeRemote("Toast")
local HitFx = makeRemote("HitFx")

local matchFolder = ReplicatedStorage:FindFirstChild("AshenMatch")
if matchFolder then
	matchFolder:Destroy()
end
matchFolder = Instance.new("Folder")
matchFolder.Name = "AshenMatch"
matchFolder.Parent = ReplicatedStorage

local teamsById = {}
local claims = {}
local banners = {}
local roundEndsAt = 0
local roundLive = true
local throneProgress = 0
local throneHouse = ""
local throneLockUntil = 0
local lastSwing = {}
local choosing = {}

for _, id in ipairs(Config.HouseOrder) do
	claims[id] = 0
	local house = Config.Houses[id]
	local team = Instance.new("Team")
	team.Name = Config.teamName(id)
	team.TeamColor = BrickColor.new(house.teamColor)
	team.AutoAssignable = false
	team.Parent = Teams
	teamsById[id] = team
end

local function syncState()
	matchFolder:SetAttribute("RoundEnds", roundEndsAt)
	matchFolder:SetAttribute("RoundLive", roundLive)
	matchFolder:SetAttribute("ThroneProgress", throneProgress)
	matchFolder:SetAttribute("ThroneHouse", throneHouse)
	matchFolder:SetAttribute("ClaimsToWin", Config.ClaimsToWin)
	for _, id in ipairs(Config.HouseOrder) do
		matchFolder:SetAttribute("Claims_" .. id, claims[id] or 0)
	end
	for _, banner in ipairs(banners) do
		matchFolder:SetAttribute("Banner_" .. banner.id, banner.owner or "Neutral")
		matchFolder:SetAttribute("BannerProgress_" .. banner.id, banner.progress or 0)
	end
end

local function toastAll(text)
	Toast:FireAllClients(text)
end

local function toast(player, text)
	Toast:FireClient(player, text)
end

local function houseIdOf(player)
	return player:GetAttribute("HouseId")
end

local function bannerCount(id)
	local n = 0
	for _, banner in ipairs(banners) do
		if banner.owner == id then
			n += 1
		end
	end
	return n
end

local function playSound(id, parent, volume)
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume or 0.5
	sound.Parent = parent or workspace
	sound:Play()
	Debris:AddItem(sound, 4)
end

-- Map ---------------------------------------------------------------------------

local function part(props)
	local piece = Instance.new(props.Class or "Part")
	piece.Name = props.Name or "Part"
	piece.Anchored = props.Anchored ~= false
	piece.CanCollide = props.CanCollide ~= false
	piece.Size = props.Size or Vector3.new(4, 1, 4)
	piece.CFrame = props.CFrame or CFrame.new(props.Position or Vector3.zero)
	piece.Color = props.Color or Color3.fromRGB(120, 116, 110)
	piece.Material = props.Material or Enum.Material.Slate
	piece.TopSurface = Enum.SurfaceType.Smooth
	piece.BottomSurface = Enum.SurfaceType.Smooth
	piece.Transparency = props.Transparency or 0
	if props.Shape then
		piece.Shape = props.Shape
	end
	piece.Parent = props.Parent
	return piece
end

local function addLight(parent, color, range, brightness)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range or 16
	light.Brightness = brightness or 1.6
	light.Parent = parent
end

local function sign(parent, text, position, color, size)
	local board = part({
		Name = "Sign",
		Parent = parent,
		Size = size or Vector3.new(10, 4, 0.4),
		CFrame = CFrame.new(position),
		Color = color or Color3.fromRGB(48, 36, 28),
		Material = Enum.Material.WoodPlanks,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(236, 226, 206)
	label.Text = text
	label.Parent = gui
	local back = Instance.new("SurfaceGui")
	back.Face = Enum.NormalId.Back
	back.Parent = board
	local label2 = label:Clone()
	label2.Parent = back
	return board
end

local function tent(parent, position, color)
	part({
		Name = "Tent",
		Parent = parent,
		Size = Vector3.new(10, 1, 8),
		Position = position + Vector3.new(0, 0.5, 0),
		Color = Color3.fromRGB(92, 70, 48),
		Material = Enum.Material.WoodPlanks,
	})
	part({
		Name = "TentCloth",
		Parent = parent,
		Size = Vector3.new(10, 5, 8),
		Position = position + Vector3.new(0, 3.2, 0),
		Color = color,
		Material = Enum.Material.Fabric,
		CanCollide = false,
	})
	local fire = part({
		Name = "Campfire",
		Parent = parent,
		Size = Vector3.new(2, 0.6, 2),
		Position = position + Vector3.new(0, 0.4, 5),
		Color = Color3.fromRGB(255, 140, 40),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	addLight(fire, Color3.fromRGB(255, 150, 60), 14, 1.4)
end

local function tree(parent, position)
	local trunk = part({
		Name = "Trunk",
		Parent = parent,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(7, 1.4, 1.4),
		CFrame = CFrame.new(position + Vector3.new(0, 3.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(92, 64, 40),
		Material = Enum.Material.WoodPlanks,
	})
	part({
		Name = "Crown",
		Parent = parent,
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(8, 7, 8),
		Position = position + Vector3.new(0, 8.2, 0),
		Color = Color3.fromRGB(62, 102, 64),
		Material = Enum.Material.Grass,
		CanCollide = false,
	})
	return trunk
end

local function buildBanner(parent, info)
	local model = Instance.new("Model")
	model.Name = "Banner_" .. info.id
	model.Parent = parent
	local base = part({
		Name = "Base",
		Parent = model,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.2, 8, 8),
		CFrame = CFrame.new(info.position + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(70, 68, 64),
		Material = Enum.Material.Slate,
	})
	local pole = part({
		Name = "Pole",
		Parent = model,
		Size = Vector3.new(0.6, 14, 0.6),
		Position = info.position + Vector3.new(0, 7, 0),
		Color = Color3.fromRGB(186, 176, 150),
		Material = Enum.Material.Metal,
	})
	local flag = part({
		Name = "Flag",
		Parent = model,
		Size = Vector3.new(0.3, 5.5, 7),
		Position = info.position + Vector3.new(0, 10, 0),
		Color = Color3.fromRGB(150, 150, 150),
		Material = Enum.Material.Fabric,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Mark"
	gui.Face = Enum.NormalId.Front
	gui.Parent = flag
	local label = Instance.new("TextLabel")
	label.Name = "Sigil"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = "BANNER"
	label.Parent = gui
	local gui2 = gui:Clone()
	gui2.Face = Enum.NormalId.Back
	gui2.Parent = flag
	local ring = part({
		Name = "Ring",
		Parent = model,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.25, 16, 16),
		CFrame = CFrame.new(info.position + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(200, 190, 160),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Transparency = 0.35,
	})
	return {
		id = info.id,
		label = info.label,
		position = info.position,
		owner = nil,
		progress = 0,
		progressHouse = nil,
		flag = flag,
		ring = ring,
		labelText = label,
		labelTextBack = gui2:FindFirstChild("Sigil"),
		pole = pole,
		base = base,
	}
end

local function paintBanner(banner)
	local house = banner.owner and Config.Houses[banner.owner]
	local color = house and house.color or Color3.fromRGB(150, 150, 150)
	local ink = house and house.ink or Color3.new(1, 1, 1)
	banner.flag.Color = color
	banner.ring.Color = color
	local text = house and house.sigil or "OPEN"
	banner.labelText.Text = text
	banner.labelText.TextColor3 = ink
	if banner.labelTextBack then
		banner.labelTextBack.Text = text
		banner.labelTextBack.TextColor3 = ink
	end
end

local function buildWyrm(parent)
	local model = Instance.new("Model")
	model.Name = "AshWyrm"
	model.Parent = parent
	local body = part({
		Name = "Body",
		Parent = model,
		Size = Vector3.new(4, 3, 16),
		Color = Color3.fromRGB(70, 28, 32),
		Material = Enum.Material.Slate,
		CanCollide = false,
	})
	model.PrimaryPart = body
	local function limb(name, size, offset, color)
		local piece = part({
			Name = name,
			Parent = model,
			Size = size,
			Color = color or Color3.fromRGB(90, 36, 40),
			Material = Enum.Material.Slate,
			CanCollide = false,
		})
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = piece
		weld.Parent = piece
		piece.CFrame = body.CFrame * offset
		return piece
	end
	limb("Neck", Vector3.new(2.2, 2, 6), CFrame.new(0, 0.6, -9))
	limb("Head", Vector3.new(3, 2.4, 4), CFrame.new(0, 1.1, -13), Color3.fromRGB(120, 48, 42))
	limb("Jaw", Vector3.new(2.2, 0.6, 3), CFrame.new(0, 0.2, -14))
	limb("WingL", Vector3.new(14, 0.4, 6), CFrame.new(-8, 1.4, -1), Color3.fromRGB(48, 18, 24))
	limb("WingR", Vector3.new(14, 0.4, 6), CFrame.new(8, 1.4, -1), Color3.fromRGB(48, 18, 24))
	limb("Tail", Vector3.new(2, 1.4, 10), CFrame.new(0, 0.2, 12))
	limb("Horn", Vector3.new(0.4, 2.4, 0.4), CFrame.new(0.6, 2.4, -13), Color3.fromRGB(230, 200, 140))
	addLight(body, Color3.fromRGB(255, 90, 40), 22, 2)
	model:PivotTo(CFrame.new(0, 42, 30))
	return model
end

local function buildMap()
	local old = workspace:FindFirstChild("AshenMap")
	if old then
		old:Destroy()
	end
	local welcome = workspace:FindFirstChild("PRESS_PLAY_F5")
	if welcome then
		welcome:Destroy()
	end
	local base = workspace:FindFirstChild("Baseplate")
	if base then
		base:Destroy()
	end

	local map = Instance.new("Folder")
	map.Name = "AshenMap"
	map.Parent = workspace

	part({
		Name = "Grass",
		Parent = map,
		Size = Vector3.new(520, 4, 520),
		Position = Vector3.new(0, -2, -20),
		Color = Color3.fromRGB(78, 112, 68),
		Material = Enum.Material.Grass,
	})
	part({
		Name = "Snowfield",
		Parent = map,
		Size = Vector3.new(520, 4, 180),
		Position = Vector3.new(0, -1.9, -360),
		Color = Color3.fromRGB(226, 234, 238),
		Material = Enum.Material.Snow,
	})

	-- Pale Wall
	part({
		Name = "PaleWallL",
		Parent = map,
		Size = Vector3.new(230, 64, 16),
		Position = Vector3.new(-145, 32, -248),
		Color = Color3.fromRGB(176, 206, 214),
		Material = Enum.Material.Glacier,
	})
	part({
		Name = "PaleWallR",
		Parent = map,
		Size = Vector3.new(230, 64, 16),
		Position = Vector3.new(145, 32, -248),
		Color = Color3.fromRGB(176, 206, 214),
		Material = Enum.Material.Glacier,
	})
	part({
		Name = "WallLintel",
		Parent = map,
		Size = Vector3.new(48, 18, 16),
		Position = Vector3.new(0, 52, -248),
		Color = Color3.fromRGB(190, 216, 222),
		Material = Enum.Material.Glacier,
	})
	sign(map, "THE PALE", Vector3.new(0, 18, -228), Color3.fromRGB(40, 60, 70), Vector3.new(16, 4, 0.5))

	-- Cindergate courtyard
	part({
		Name = "Courtyard",
		Parent = map,
		Size = Vector3.new(92, 1, 78),
		Position = Vector3.new(0, 0.5, -16),
		Color = Color3.fromRGB(132, 126, 116),
		Material = Enum.Material.Cobblestone,
	})

	local function wall(name, size, position)
		part({
			Name = name,
			Parent = map,
			Size = size,
			Position = position,
			Color = Color3.fromRGB(104, 100, 94),
			Material = Enum.Material.Slate,
		})
	end
	wall("WallN_L", Vector3.new(34, 16, 3), Vector3.new(-29, 8.5, -54))
	wall("WallN_R", Vector3.new(34, 16, 3), Vector3.new(29, 8.5, -54))
	part({
		Name = "HallDoorLintel",
		Parent = map,
		Size = Vector3.new(26, 4, 3),
		Position = Vector3.new(0, 14.5, -54),
		Color = Color3.fromRGB(88, 84, 78),
		Material = Enum.Material.Slate,
	})
	wall("WallS_L", Vector3.new(36, 16, 3), Vector3.new(-28, 8.5, 22))
	wall("WallS_R", Vector3.new(36, 16, 3), Vector3.new(28, 8.5, 22))
	wall("WallW", Vector3.new(3, 16, 78), Vector3.new(-46, 8.5, -16))
	wall("WallE", Vector3.new(3, 16, 78), Vector3.new(46, 8.5, -16))
	part({
		Name = "GateLintel",
		Parent = map,
		Size = Vector3.new(22, 4, 3),
		Position = Vector3.new(0, 14.5, 22),
		Color = Color3.fromRGB(88, 84, 78),
		Material = Enum.Material.Slate,
	})

	local towerColor = Color3.fromRGB(90, 86, 80)
	for _, spot in ipairs({
		Vector3.new(-46, 0, 22),
		Vector3.new(46, 0, 22),
		Vector3.new(-46, 0, -54),
		Vector3.new(46, 0, -54),
	}) do
		part({
			Name = "Tower",
			Parent = map,
			Size = Vector3.new(10, 28, 10),
			Position = spot + Vector3.new(0, 14, 0),
			Color = towerColor,
			Material = Enum.Material.Slate,
		})
		part({
			Name = "TowerCap",
			Parent = map,
			Size = Vector3.new(12, 3, 12),
			Position = spot + Vector3.new(0, 29, 0),
			Color = Color3.fromRGB(120, 36, 40),
			Material = Enum.Material.Slate,
		})
	end

	-- Hall and Cinder Seat
	local throne = Config.ThronePosition
	part({
		Name = "HallFloor",
		Parent = map,
		Size = Vector3.new(36, 1, 40),
		Position = throne + Vector3.new(0, 0.55, 6),
		Color = Color3.fromRGB(96, 90, 84),
		Material = Enum.Material.Slate,
	})
	part({
		Name = "Carpet",
		Parent = map,
		Size = Vector3.new(6, 0.2, 34),
		Position = throne + Vector3.new(0, 1.1, 8),
		Color = Color3.fromRGB(122, 28, 34),
		Material = Enum.Material.Fabric,
		CanCollide = false,
	})
	wall("HallW", Vector3.new(2, 14, 40), throne + Vector3.new(-18, 8, 6))
	wall("HallE", Vector3.new(2, 14, 40), throne + Vector3.new(18, 8, 6))
	wall("HallN", Vector3.new(36, 14, 2), throne + Vector3.new(0, 8, -14))
	part({
		Name = "HallRoof",
		Parent = map,
		Size = Vector3.new(40, 1.2, 44),
		Position = throne + Vector3.new(0, 15.2, 6),
		Color = Color3.fromRGB(62, 42, 40),
		Material = Enum.Material.Slate,
	})
	for i = 1, 4 do
		part({
			Name = "Step",
			Parent = map,
			Size = Vector3.new(10, 0.6, 3),
			Position = throne + Vector3.new(0, 1.2 + (i - 1) * 0.45, 8 - (i - 1) * 2.2),
			Color = Color3.fromRGB(70, 66, 62),
			Material = Enum.Material.Slate,
		})
	end
	local pad = part({
		Name = "ThronePad",
		Parent = map,
		Size = Vector3.new(8, 1, 8),
		Position = throne + Vector3.new(0, 3.2, 0),
		Color = Color3.fromRGB(40, 38, 42),
		Material = Enum.Material.Basalt,
	})
	part({
		Name = "Seat",
		Parent = map,
		Size = Vector3.new(5, 1.2, 3),
		Position = throne + Vector3.new(0, 4.2, -1.2),
		Color = Color3.fromRGB(36, 34, 38),
		Material = Enum.Material.Metal,
	})
	part({
		Name = "SeatBack",
		Parent = map,
		Size = Vector3.new(6, 7, 1),
		Position = throne + Vector3.new(0, 7.2, -2.6),
		Color = Color3.fromRGB(28, 26, 30),
		Material = Enum.Material.Metal,
	})
	for _, x in ipairs({ -2.2, 2.2 }) do
		part({
			Name = "ThroneSpike",
			Parent = map,
			Size = Vector3.new(0.35, 3.2, 0.35),
			CFrame = CFrame.new(throne + Vector3.new(x, 10.2, -2.6)) * CFrame.Angles(0, 0, math.rad(x > 0 and 12 or -12)),
			Color = Color3.fromRGB(210, 200, 180),
			Material = Enum.Material.Metal,
			CanCollide = false,
		})
	end
	addLight(pad, Color3.fromRGB(255, 150, 70), 20, 1.5)
	sign(map, "THE CINDER SEAT", throne + Vector3.new(0, 11, 16), Color3.fromRGB(48, 28, 24), Vector3.new(14, 3, 0.4))

	-- Armory + maester inside the yard
	local smithBench = part({
		Name = "Armory",
		Parent = map,
		Size = Vector3.new(8, 4, 3),
		Position = Vector3.new(30, 3, -16),
		Color = Color3.fromRGB(84, 62, 44),
		Material = Enum.Material.WoodPlanks,
	})
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BuyRune"
	prompt.ActionText = "Buy Rune Blade"
	prompt.ObjectText = Config.RuneCost .. " coins"
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 12
	prompt.Parent = smithBench
	sign(map, "ARMORY", Vector3.new(30, 7, -12), Color3.fromRGB(70, 48, 32), Vector3.new(8, 2.2, 0.3))

	local maester = part({
		Name = "MaesterStone",
		Parent = map,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(3, 6, 6),
		CFrame = CFrame.new(-30, 2, -16) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(150, 148, 140),
		Material = Enum.Material.Slate,
	})
	local omen = Instance.new("ProximityPrompt")
	omen.Name = "Omen"
	omen.ActionText = "Hear the omen"
	omen.ObjectText = "Maester Orlen"
	omen.HoldDuration = 0.2
	omen.MaxActivationDistance = 12
	omen.Parent = maester

	sign(map, "CINDERGATE", Vector3.new(0, 10, 30), Color3.fromRGB(54, 40, 36), Vector3.new(18, 4, 0.5))

	-- Lobby yard (safe)
	part({
		Name = "LobbyStones",
		Parent = map,
		Size = Vector3.new(48, 1, 36),
		Position = Vector3.new(0, 0.45, 88),
		Color = Color3.fromRGB(126, 120, 110),
		Material = Enum.Material.Cobblestone,
	})
	sign(map, "SWEAR A HOUSE  THEN MARCH", Vector3.new(0, 10, 70), Color3.fromRGB(40, 36, 32), Vector3.new(18, 3, 0.4))

	for id, campPos in pairs(Config.Camps) do
		tent(map, campPos, Config.Houses[id].color)
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = id .. "Spawn"
		spawn.Size = Vector3.new(8, 1, 8)
		spawn.Position = campPos + Vector3.new(0, 1.2, -8)
		spawn.Anchored = true
		spawn.Neutral = false
		spawn.AllowTeamChangeOnTouch = false
		spawn.TeamColor = BrickColor.new(Config.Houses[id].teamColor)
		spawn.Duration = 0
		spawn.Material = Enum.Material.Neon
		spawn.Color = Config.Houses[id].color
		spawn.Transparency = 0.35
		spawn.Parent = map
	end

	table.clear(banners)
	for _, info in ipairs(Config.Banners) do
		local banner = buildBanner(map, info)
		paintBanner(banner)
		table.insert(banners, banner)
	end

	for _, spot in ipairs({
		Vector3.new(70, 0, -40),
		Vector3.new(-70, 0, -30),
		Vector3.new(40, 0, 50),
		Vector3.new(-50, 0, 130),
		Vector3.new(170, 0, 20),
		Vector3.new(-170, 0, -20),
		Vector3.new(20, 0, -200),
		Vector3.new(-24, 0, 190),
		Vector3.new(200, 0, -80),
		Vector3.new(-190, 0, 100),
	}) do
		tree(map, spot)
	end

	local wyrm = buildWyrm(map)

	omen.Triggered:Connect(function(player)
		local id = houseIdOf(player)
		if not id then
			toast(player, "Swear to a house before you ask the maester for war.")
			return
		end
		toast(player, "Maester Orlen: Hold two banners, then stand upon the Cinder Seat. Three claims wins the realm. The Pale freezes everyone but Frostholm.")
	end)

	prompt.Triggered:Connect(function(player)
		if not houseIdOf(player) then
			toast(player, "The smith will not arm a sworn-less wanderer.")
			return
		end
		if player:GetAttribute("RuneBlade") then
			toast(player, "You already carry the rune blade.")
			return
		end
		local coins = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Coins")
		if not coins or coins.Value < Config.RuneCost then
			toast(player, "The smith wants " .. Config.RuneCost .. " coins. You have " .. (coins and coins.Value or 0) .. ".")
			return
		end
		coins.Value -= Config.RuneCost
		player:SetAttribute("RuneBlade", true)
		giveSword(player)
		toast(player, "The rune blade is yours. It bites deeper.")
		playSound("rbxasset://sounds/unsheath.wav", player.Character, 0.6)
	end)

	return map, wyrm
end

-- Loadout ----------------------------------------------------------------------

function giveSword(player)
	local backpack = player:FindFirstChild("Backpack")
	local character = player.Character
	local function strip(container)
		if not container then
			return
		end
		for _, child in ipairs(container:GetChildren()) do
			if child:IsA("Tool") then
				child:Destroy()
			end
		end
	end
	strip(backpack)
	strip(character)
	if not backpack then
		return
	end

	local rune = player:GetAttribute("RuneBlade") == true
	local tool = Instance.new("Tool")
	tool.Name = rune and "Rune Blade" or "Longsword"
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ToolTip = rune and "A heavier cut" or "Click to strike. Hold Q to guard."

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.28, 1.15, 0.28)
	handle.Color = rune and Color3.fromRGB(92, 28, 28) or Color3.fromRGB(92, 64, 42)
	handle.Material = Enum.Material.WoodPlanks
	handle.CanCollide = false
	handle.Parent = tool

	local blade = Instance.new("Part")
	blade.Name = "Blade"
	blade.Size = Vector3.new(0.18, 3.5, 0.55)
	blade.Color = rune and Color3.fromRGB(255, 170, 90) or Color3.fromRGB(214, 220, 228)
	blade.Material = rune and Enum.Material.Neon or Enum.Material.Metal
	blade.CanCollide = false
	blade.Massless = true
	blade.Parent = tool
	local weld = Instance.new("Weld")
	weld.Part0 = handle
	weld.Part1 = blade
	weld.C0 = CFrame.new(0, 2.2, 0)
	weld.Parent = handle

	local guard = Instance.new("Part")
	guard.Name = "Crossguard"
	guard.Size = Vector3.new(1.3, 0.18, 0.22)
	guard.Color = Color3.fromRGB(196, 168, 72)
	guard.Material = Enum.Material.Metal
	guard.CanCollide = false
	guard.Massless = true
	guard.Parent = tool
	local weld2 = Instance.new("Weld")
	weld2.Part0 = handle
	weld2.Part1 = guard
	weld2.C0 = CFrame.new(0, 0.7, 0)
	weld2.Parent = handle

	tool.Grip = CFrame.new(0, -0.4, 0) * CFrame.Angles(math.rad(-90), 0, 0)
	tool.Parent = backpack

	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:EquipTool(tool)
	end
end

local function applySpeed(player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local speed = houseIdOf(player) == "Tideholm" and Config.TideholmSpeed or Config.BaseSpeed
	if player:GetAttribute("Blocking") then
		speed = 8
	end
	humanoid.WalkSpeed = speed
end

local function awardCoins(player, amount, houseBonus)
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		return
	end
	local coins = stats:FindFirstChild("Coins")
	if coins then
		local bonus = 0
		if houseBonus and houseIdOf(player) == "Goldmere" then
			bonus = Config.GoldmereBonusCoins
		end
		coins.Value += amount + bonus
	end
end

local function noteKill(player)
	local stats = player:FindFirstChild("leaderstats")
	local kills = stats and stats:FindFirstChild("Kills")
	if kills then
		kills.Value += 1
	end
end

local function onHumanoidDied(humanoid, victimPlayer)
	local attackerId = humanoid:GetAttribute("LastAttacker")
	if typeof(attackerId) ~= "number" or attackerId <= 0 then
		return
	end
	local attacker = Players:GetPlayerByUserId(attackerId)
	if not attacker or attacker == victimPlayer then
		return
	end
	noteKill(attacker)
	awardCoins(attacker, victimPlayer and Config.PlayerKillCoins or Config.RaiderKillCoins, true)
	local victimName = victimPlayer and victimPlayer.DisplayName or "Ash Marauder"
	toastAll(attacker.DisplayName .. " felled " .. victimName)
end

local function setupCharacter(player, character)
	local humanoid = character:WaitForChild("Humanoid", 8)
	local root = character:WaitForChild("HumanoidRootPart", 8)
	if not humanoid or not root then
		return
	end
	player:SetAttribute("Blocking", false)
	humanoid.MaxHealth = 100
	humanoid.Health = 100
	humanoid.DisplayName = player.DisplayName
	applySpeed(player)

	local shield = Instance.new("ForceField")
	shield.Visible = true
	shield.Parent = character
	Debris:AddItem(shield, Config.SpawnShield)

	if houseIdOf(player) then
		giveSword(player)
	end

	humanoid.Died:Connect(function()
		player:SetAttribute("Blocking", false)
		onHumanoidDied(humanoid, player)
	end)
end

local function ensureStats(player)
	if player:FindFirstChild("leaderstats") then
		return
	end
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Parent = stats
	local kills = Instance.new("IntValue")
	kills.Name = "Kills"
	kills.Parent = stats
	local claimStat = Instance.new("IntValue")
	claimStat.Name = "Claims"
	claimStat.Parent = stats
	stats.Parent = player
end

-- Combat -----------------------------------------------------------------------

local function swordDamageFor(player)
	local amount = player:GetAttribute("RuneBlade") and Config.RuneDamage or Config.SwordDamage
	if houseIdOf(player) == "Wyrmreach" then
		amount = math.floor(amount * 1.15)
	end
	if houseIdOf(player) == "Frostholm" then
		local clock = Lighting.ClockTime
		if clock >= 18 or clock < 6 then
			amount = math.floor(amount * Config.FrostholmNightBonus)
		end
	end
	return amount
end

local function tryHit(origin, look, targetRoot, targetHumanoid, amount, attackerPlayer)
	if not targetRoot or not targetHumanoid or targetHumanoid.Health <= 0 then
		return false
	end
	local delta = targetRoot.Position - origin
	if math.abs(delta.Y) > 7 then
		return false
	end
	local flat = Vector3.new(delta.X, 0, delta.Z)
	if flat.Magnitude > Config.SwordRange or flat.Magnitude < 0.05 then
		return false
	end
	local flatLook = Vector3.new(look.X, 0, look.Z)
	if flatLook.Magnitude < 0.05 then
		return false
	end
	if flat.Unit:Dot(flatLook.Unit) < 0.25 then
		return false
	end
	if Config.inSafe(origin) or Config.inSafe(targetRoot.Position) then
		return false
	end
	local taken = amount
	local targetPlayer = Players:GetPlayerFromCharacter(targetHumanoid.Parent)
	if targetPlayer and targetPlayer:GetAttribute("Blocking") then
		local theirLook = targetRoot.CFrame.LookVector
		local face = Vector3.new(theirLook.X, 0, theirLook.Z)
		if face.Magnitude > 0.05 and face.Unit:Dot((-flat).Unit) > 0.15 then
			taken = math.max(1, math.floor(amount * 0.28))
		end
	end
	targetHumanoid:SetAttribute("LastAttacker", attackerPlayer.UserId)
	targetHumanoid:TakeDamage(taken)
	HitFx:FireAllClients(targetRoot.Position + Vector3.new(0, 2, 0), taken)
	return true
end

Swing.OnServerEvent:Connect(function(player)
	if not roundLive then
		return
	end
	if not houseIdOf(player) then
		return
	end
	local now = os.clock()
	if lastSwing[player] and now - lastSwing[player] < Config.SwordCooldown then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 then
		return
	end
	lastSwing[player] = now
	playSound("rbxasset://sounds/swordslash.wav", root, 0.45)
	local amount = swordDamageFor(player)
	local origin = root.Position
	local look = root.CFrame.LookVector

	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player and other.Team ~= player.Team then
			local otherCharacter = other.Character
			local otherHumanoid = otherCharacter and otherCharacter:FindFirstChildOfClass("Humanoid")
			local otherRoot = otherCharacter and otherCharacter:FindFirstChild("HumanoidRootPart")
			tryHit(origin, look, otherRoot, otherHumanoid, amount, player)
		end
	end

	local raiders = workspace:FindFirstChild("AshRaiders")
	if raiders then
		for _, model in ipairs(raiders:GetChildren()) do
			local otherHumanoid = model:FindFirstChildOfClass("Humanoid")
			local otherRoot = model:FindFirstChild("HumanoidRootPart")
			tryHit(origin, look, otherRoot, otherHumanoid, amount, player)
		end
	end
end)

Block.OnServerEvent:Connect(function(player, isBlocking)
	if typeof(isBlocking) ~= "boolean" then
		return
	end
	if not houseIdOf(player) then
		return
	end
	player:SetAttribute("Blocking", isBlocking)
	applySpeed(player)
end)

-- Round ------------------------------------------------------------------------

local function resetRound()
	for _, id in ipairs(Config.HouseOrder) do
		claims[id] = 0
	end
	for _, banner in ipairs(banners) do
		banner.owner = nil
		banner.progress = 0
		banner.progressHouse = nil
		paintBanner(banner)
	end
	throneProgress = 0
	throneHouse = ""
	roundLive = true
	roundEndsAt = workspace:GetServerTimeNow() + Config.RoundLength
	matchFolder:SetAttribute("Winner", "")
	syncState()
	for _, player in ipairs(Players:GetPlayers()) do
		if houseIdOf(player) then
			player:LoadCharacter()
		end
	end
end

local function endRound(winnerId, reason)
	if not roundLive then
		return
	end
	roundLive = false
	local house = winnerId and Config.Houses[winnerId]
	matchFolder:SetAttribute("Winner", winnerId or "")
	syncState()
	toastAll(reason)
	if house then
		playSound("rbxasset://sounds/victory.wav", workspace, 0.7)
	end
	task.delay(Config.Intermission, function()
		resetRound()
		toastAll("A new war begins. Banners are unclaimed. The Cinder Seat is empty.")
	end)
end

local function addClaim(id, player)
	claims[id] = (claims[id] or 0) + 1
	local stats = player:FindFirstChild("leaderstats")
	local claimStat = stats and stats:FindFirstChild("Claims")
	if claimStat then
		claimStat.Value += 1
	end
	awardCoins(player, Config.ClaimCoins)
	toastAll(Config.Houses[id].name .. " claimed the Cinder Seat (" .. claims[id] .. "/" .. Config.ClaimsToWin .. ")")
	if claims[id] >= Config.ClaimsToWin then
		endRound(id, Config.Houses[id].name .. " holds the realm.")
	end
end

local function updateBanners(dt)
	for _, banner in ipairs(banners) do
		local present = {}
		local count = 0
		for _, player in ipairs(Players:GetPlayers()) do
			local id = houseIdOf(player)
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if id and humanoid and root and humanoid.Health > 0 then
				local offset = root.Position - banner.position
				local flat = Vector3.new(offset.X, 0, offset.Z)
				if flat.Magnitude <= 14 and math.abs(offset.Y) < 12 then
					present[id] = (present[id] or 0) + 1
					count += 1
				end
			end
		end
		local housesHere = 0
		local only = nil
		for id in pairs(present) do
			housesHere += 1
			only = id
		end
		if housesHere == 1 and only ~= banner.owner then
			if banner.progressHouse ~= only then
				banner.progressHouse = only
				banner.progress = 0
			end
			local speed = 1 + math.max(0, (present[only] or 1) - 1) * 0.4
			banner.progress += dt * speed
			if banner.progress >= Config.BannerCaptureTime then
				banner.owner = only
				banner.progress = 0
				paintBanner(banner)
				toastAll(Config.Houses[only].name .. " raised the " .. banner.label .. ".")
			end
		elseif housesHere == 0 then
			if banner.progress > 0 then
				banner.progress = math.max(0, banner.progress - dt * 0.8)
			end
		else
			banner.progress = math.max(0, banner.progress - dt)
		end
		local ratio = math.clamp(banner.progress / Config.BannerCaptureTime, 0, 1)
		banner.ring.Transparency = 0.45 - ratio * 0.3
	end
end

local function updateThrone(dt)
	local padPos = Config.ThronePosition + Vector3.new(0, 4, 0)
	local present = {}
	local claimer = nil
	for _, player in ipairs(Players:GetPlayers()) do
		local id = houseIdOf(player)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if id and humanoid and root and humanoid.Health > 0 then
			local offset = root.Position - padPos
			local flat = Vector3.new(offset.X, 0, offset.Z)
			if flat.Magnitude <= 7 and math.abs(offset.Y) < 8 then
				present[id] = player
			end
		end
	end
	local housesHere = 0
	local only = nil
	for id, player in pairs(present) do
		housesHere += 1
		only = id
		claimer = player
	end
	local now = workspace:GetServerTimeNow()
	if housesHere == 1 and bannerCount(only) >= Config.ThroneBannersNeeded and now >= throneLockUntil then
		if throneHouse ~= only then
			throneHouse = only
			throneProgress = 0
		end
		throneProgress += dt / Config.ThroneChannelTime
		if throneProgress >= 1 and claimer then
			throneProgress = 0
			throneLockUntil = now + 12
			addClaim(only, claimer)
		end
	else
		if housesHere == 1 and only and bannerCount(only) < Config.ThroneBannersNeeded then
			throneHouse = only
		elseif housesHere ~= 1 then
			throneHouse = ""
		end
		throneProgress = math.max(0, throneProgress - dt / 2)
	end
end

local function environmentTick()
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid and root and humanoid.Health > 0 and root.Position.Z < Config.ColdZ then
			if houseIdOf(player) == "Frostholm" then
				humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + 4)
			elseif not Config.inSafe(root.Position) then
				humanoid:TakeDamage(Config.ColdDamage)
			end
		end
	end
end

-- Raiders ----------------------------------------------------------------------

local function spawnRaider(position, folder)
	local description = Instance.new("HumanoidDescription")
	description.HeadColor = Color3.fromRGB(168, 166, 160)
	description.TorsoColor = Color3.fromRGB(48, 44, 42)
	description.LeftArmColor = Color3.fromRGB(62, 56, 52)
	description.RightArmColor = Color3.fromRGB(62, 56, 52)
	description.LeftLegColor = Color3.fromRGB(32, 30, 30)
	description.RightLegColor = Color3.fromRGB(32, 30, 30)

	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	description:Destroy()
	if not ok or typeof(model) ~= "Instance" then
		warn("[Ashen Realm] Marauder rig failed: " .. tostring(model))
		return nil
	end

	model.Name = "AshMarauder"
	model.Parent = folder
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not hrp then
		model:Destroy()
		return nil
	end
	humanoid.MaxHealth = 80
	humanoid.Health = 80
	humanoid.WalkSpeed = 12
	humanoid.DisplayName = "Ash Marauder"
	humanoid.NameDisplayDistance = 80
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.DisplayWhenDamaged
	model:PivotTo(CFrame.new(position + Vector3.new(0, 4, 0)))
	pcall(function()
		hrp:SetNetworkOwner(nil)
	end)

	local path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = true,
	})
	local nextHit = 0

	humanoid.Died:Connect(function()
		onHumanoidDied(humanoid, nil)
		task.delay(8, function()
			if model.Parent then
				model:Destroy()
			end
			if folder.Parent then
				spawnRaider(position, folder)
			end
		end)
	end)

	task.spawn(function()
		while model.Parent and humanoid.Health > 0 do
			local bestRoot = nil
			local bestDist = 170
			for _, player in ipairs(Players:GetPlayers()) do
				local character = player.Character
				local otherHumanoid = character and character:FindFirstChildOfClass("Humanoid")
				local otherRoot = character and character:FindFirstChild("HumanoidRootPart")
				if otherHumanoid and otherRoot and otherHumanoid.Health > 0 and not Config.inSafe(otherRoot.Position) then
					local dist = (otherRoot.Position - hrp.Position).Magnitude
					if dist < bestDist then
						bestDist = dist
						bestRoot = otherRoot
					end
				end
			end
			if bestRoot and bestDist < 7 then
				local now = os.clock()
				if now >= nextHit then
					nextHit = now + 1.15
					local victimHumanoid = bestRoot.Parent:FindFirstChildOfClass("Humanoid")
					if victimHumanoid and roundLive then
						victimHumanoid:SetAttribute("LastAttacker", 0)
						victimHumanoid:TakeDamage(13)
						HitFx:FireAllClients(bestRoot.Position + Vector3.new(0, 2, 0), 13)
					end
				end
				humanoid:MoveTo(bestRoot.Position)
			elseif bestRoot then
				local goal = bestRoot.Position
				local computed = pcall(function()
					path:ComputeAsync(hrp.Position, goal)
				end)
				if computed and path.Status == Enum.PathStatus.Success then
					local waypoints = path:GetWaypoints()
					local step = waypoints[2] or waypoints[1]
					if step then
						humanoid:MoveTo(step.Position)
					end
				else
					humanoid:MoveTo(goal)
				end
			else
				humanoid:MoveTo(position + Vector3.new(math.random(-18, 18), 0, math.random(-18, 18)))
			end
			task.wait(0.7)
		end
	end)

	return model
end

-- Dragonfire -------------------------------------------------------------------

local function dragonLoop(wyrm)
	local angle = 0
	RunService.Heartbeat:Connect(function(dt)
		if not wyrm.Parent then
			return
		end
		angle += dt * 0.28
		local x = math.cos(angle) * 110
		local z = math.sin(angle) * 80 + 10
		local y = 40 + math.sin(angle * 2) * 5
		wyrm:PivotTo(CFrame.new(x, y, z) * CFrame.Angles(0, -angle + math.rad(90), math.rad(-10)))
	end)

	task.spawn(function()
		while wyrm.Parent do
			task.wait(24)
			if not roundLive then
				continue
			end
			local candidates = {}
			for _, player in ipairs(Players:GetPlayers()) do
				if houseIdOf(player) and houseIdOf(player) ~= "Wyrmreach" then
					local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
					local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
					if root and humanoid and humanoid.Health > 0 and not Config.inSafe(root.Position) then
						table.insert(candidates, root)
					end
				end
			end
			local pos
			if #candidates > 0 then
				pos = candidates[math.random(#candidates)].Position
			else
				pos = Vector3.new(math.random(-70, 70), 0, math.random(-30, 90))
			end
			local zone = part({
				Name = "Dragonfire",
				Parent = workspace.AshenMap,
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(1.2, 30, 30),
				CFrame = CFrame.new(pos.X, 1.2, pos.Z) * CFrame.Angles(0, 0, math.rad(90)),
				Color = Color3.fromRGB(255, 210, 80),
				Material = Enum.Material.Neon,
				CanCollide = false,
				Transparency = 0.45,
			})
			toastAll("The ash wyrm dives. Leave the gold ring.")
			task.wait(1.6)
			if zone.Parent then
				zone.Color = Color3.fromRGB(255, 80, 30)
				zone.Transparency = 0.25
			end
			local started = os.clock()
			while os.clock() - started < 2.6 and zone.Parent and roundLive do
				for _, player in ipairs(Players:GetPlayers()) do
					if houseIdOf(player) ~= "Wyrmreach" then
						local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
						local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
						if root and humanoid and humanoid.Health > 0 then
							local flat = Vector3.new(root.Position.X - pos.X, 0, root.Position.Z - pos.Z)
							if flat.Magnitude <= 16 and not Config.inSafe(root.Position) then
								humanoid:TakeDamage(10)
							end
						end
					end
				end
				local raiders = workspace:FindFirstChild("AshRaiders")
				if raiders then
					for _, model in ipairs(raiders:GetChildren()) do
						local root = model:FindFirstChild("HumanoidRootPart")
						local humanoid = model:FindFirstChildOfClass("Humanoid")
						if root and humanoid and humanoid.Health > 0 then
							local flat = Vector3.new(root.Position.X - pos.X, 0, root.Position.Z - pos.Z)
							if flat.Magnitude <= 16 then
								humanoid:TakeDamage(14)
							end
						end
					end
				end
				task.wait(0.45)
			end
			if zone.Parent then
				zone:Destroy()
			end
		end
	end)
end

-- Players ----------------------------------------------------------------------

local function onPlayerAdded(player)
	ensureStats(player)
	player:SetAttribute("Blocking", false)
	player.CharacterAdded:Connect(function(character)
		setupCharacter(player, character)
	end)
end

ChooseHouse.OnServerEvent:Connect(function(player, houseId)
	if typeof(houseId) ~= "string" or not Config.Houses[houseId] then
		return
	end
	if houseIdOf(player) or choosing[player] then
		return
	end
	choosing[player] = true
	local team = teamsById[houseId]
	player.Team = team
	player:SetAttribute("HouseId", houseId)
	toast(player, "You are sworn to " .. Config.Houses[houseId].name .. ". " .. Config.Houses[houseId].motto)
	toastAll(player.DisplayName .. " swore to " .. Config.Houses[houseId].name .. ".")
	player:LoadCharacter()
end)

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

Players.PlayerRemoving:Connect(function(player)
	lastSwing[player] = nil
	choosing[player] = nil
end)

-- World start ------------------------------------------------------------------

Lighting.ClockTime = 17.4
Lighting.Brightness = 2.1
Lighting.Ambient = Color3.fromRGB(78, 82, 96)
Lighting.OutdoorAmbient = Color3.fromRGB(128, 132, 142)
Lighting.FogColor = Color3.fromRGB(168, 176, 186)
Lighting.FogStart = 160
Lighting.FogEnd = 760
Lighting.GlobalShadows = true
if not Lighting:FindFirstChildOfClass("Atmosphere") then
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.32
	atmosphere.Offset = 0.15
	atmosphere.Color = Color3.fromRGB(190, 198, 206)
	atmosphere.Decay = Color3.fromRGB(120, 110, 100)
	atmosphere.Glare = 0.15
	atmosphere.Haze = 1.2
	atmosphere.Parent = Lighting
end

local _, wyrm = buildMap()

local raiderFolder = workspace:FindFirstChild("AshRaiders")
if raiderFolder then
	raiderFolder:Destroy()
end
raiderFolder = Instance.new("Folder")
raiderFolder.Name = "AshRaiders"
raiderFolder.Parent = workspace
for _, spot in ipairs(Config.RaiderSpawns) do
	spawnRaider(spot, raiderFolder)
end

roundEndsAt = workspace:GetServerTimeNow() + Config.RoundLength
matchFolder:SetAttribute("Winner", "")
syncState()
dragonLoop(wyrm)

local bannerTick = 0
local coldTick = 0
RunService.Heartbeat:Connect(function(dt)
	dt = math.min(dt, 0.1)
	Lighting.ClockTime = (Lighting.ClockTime + dt * 0.045) % 24
	if not roundLive then
		return
	end
	bannerTick += dt
	coldTick += dt
	if bannerTick >= 0.25 then
		local step = bannerTick
		bannerTick = 0
		updateBanners(step)
		updateThrone(step)
		syncState()
		if workspace:GetServerTimeNow() >= roundEndsAt then
			local bestId = nil
			local bestClaims = -1
			local tie = false
			for _, id in ipairs(Config.HouseOrder) do
				local n = claims[id] or 0
				if n > bestClaims then
					bestClaims = n
					bestId = id
					tie = false
				elseif n == bestClaims then
					tie = true
				end
			end
			if bestClaims <= 0 or tie then
				endRound(nil, "The horn sounds. No house held the Cinder Seat. The war begins again.")
			else
				endRound(bestId, "Time. " .. Config.Houses[bestId].name .. " kept the seat.")
			end
		end
	end
	if coldTick >= 1 then
		coldTick = 0
		environmentTick()
	end
end)

print("[Ashen Realm] The Cinder Seat is empty. Four houses remain.")
