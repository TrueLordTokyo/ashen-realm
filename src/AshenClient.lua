-- Ashen Realm client. House oath, HUD, sword input, minimap.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("AshenConfig"))
local remotes = ReplicatedStorage:WaitForChild("AshenRemotes")
local matchFolder = ReplicatedStorage:WaitForChild("AshenMatch")
local ChooseHouse = remotes:WaitForChild("ChooseHouse")
local Swing = remotes:WaitForChild("Swing")
local Block = remotes:WaitForChild("Block")
local Toast = remotes:WaitForChild("Toast")
local HitFx = remotes:WaitForChild("HitFx")

player.CameraMaxZoomDistance = 48
player.CameraMinZoomDistance = 8

local gui = Instance.new("ScreenGui")
gui.Name = "AshenRealm"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 8)
	c.Parent = parent
	return c
end

local function stroke(parent, color, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color or Color3.fromRGB(220, 200, 160)
	s.Thickness = thickness or 1
	s.Transparency = 0.25
	s.Parent = parent
	return s
end

-- Oath screen ------------------------------------------------------------------

local picker = Instance.new("Frame")
picker.Name = "Oath"
picker.Size = UDim2.fromScale(1, 1)
picker.BackgroundColor3 = Color3.fromRGB(10, 12, 16)
picker.BackgroundTransparency = 0.12
picker.BorderSizePixel = 0
picker.Parent = gui

local veil = Instance.new("Frame")
veil.Size = UDim2.fromScale(1, 1)
veil.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
veil.BackgroundTransparency = 0.35
veil.BorderSizePixel = 0
veil.Parent = picker

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromScale(0.08, 0.05)
title.Size = UDim2.fromScale(0.84, 0.09)
title.Font = Enum.Font.Garamond
title.Text = "ASHEN REALM"
title.TextColor3 = Color3.fromRGB(236, 220, 186)
title.TextScaled = true
title.Parent = picker

local sub = Instance.new("TextLabel")
sub.BackgroundTransparency = 1
sub.Position = UDim2.fromScale(0.12, 0.145)
sub.Size = UDim2.fromScale(0.76, 0.06)
sub.Font = Enum.Font.Gotham
sub.Text = "The Cinder Seat is empty. Four houses remain. Swear, then take it."
sub.TextColor3 = Color3.fromRGB(186, 186, 196)
sub.TextScaled = true
sub.Parent = picker

local row = Instance.new("Frame")
row.BackgroundTransparency = 1
row.Position = UDim2.fromScale(0.04, 0.24)
row.Size = UDim2.fromScale(0.92, 0.58)
row.Parent = picker

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Center
layout.Padding = UDim.new(0.015, 0)
layout.Parent = row

local controls = Instance.new("TextLabel")
controls.BackgroundTransparency = 1
controls.Position = UDim2.fromScale(0.1, 0.86)
controls.Size = UDim2.fromScale(0.8, 0.08)
controls.Font = Enum.Font.Gotham
controls.Text = "Click to strike    ·    Hold Q to guard    ·    Stand in a ring to raise a banner    ·    Two banners, then the throne"
controls.TextColor3 = Color3.fromRGB(160, 160, 170)
controls.TextScaled = true
controls.Parent = picker

local busy = false

for _, id in ipairs(Config.HouseOrder) do
	local house = Config.Houses[id]
	local card = Instance.new("TextButton")
	card.Name = id
	card.AutoButtonColor = true
	card.Text = ""
	card.Size = UDim2.fromScale(0.23, 0.96)
	card.BackgroundColor3 = house.color
	card.BorderSizePixel = 0
	card.Parent = row
	corner(card, 14)
	stroke(card, house.accent, 1.5)

	local sigil = Instance.new("TextLabel")
	sigil.BackgroundTransparency = 1
	sigil.Position = UDim2.fromScale(0.08, 0.05)
	sigil.Size = UDim2.fromScale(0.84, 0.16)
	sigil.Font = Enum.Font.GothamBlack
	sigil.Text = house.sigil
	sigil.TextColor3 = house.ink
	sigil.TextScaled = true
	sigil.Parent = card

	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Position = UDim2.fromScale(0.08, 0.23)
	name.Size = UDim2.fromScale(0.84, 0.12)
	name.Font = Enum.Font.Garamond
	name.Text = house.name
	name.TextColor3 = house.ink
	name.TextScaled = true
	name.Parent = card

	local motto = Instance.new("TextLabel")
	motto.BackgroundTransparency = 1
	motto.Position = UDim2.fromScale(0.08, 0.37)
	motto.Size = UDim2.fromScale(0.84, 0.1)
	motto.Font = Enum.Font.GothamMedium
	motto.Text = house.motto
	motto.TextColor3 = house.ink
	motto.TextTransparency = 0.15
	motto.TextScaled = true
	motto.Parent = card

	local blurb = Instance.new("TextLabel")
	blurb.BackgroundTransparency = 1
	blurb.Position = UDim2.fromScale(0.08, 0.5)
	blurb.Size = UDim2.fromScale(0.84, 0.28)
	blurb.Font = Enum.Font.Gotham
	blurb.Text = house.blurb
	blurb.TextColor3 = house.ink
	blurb.TextWrapped = true
	blurb.TextYAlignment = Enum.TextYAlignment.Top
	blurb.TextSize = 15
	blurb.Parent = card

	local bonus = Instance.new("TextLabel")
	bonus.BackgroundTransparency = 0.35
	bonus.BackgroundColor3 = Color3.new(0, 0, 0)
	bonus.Position = UDim2.fromScale(0.08, 0.82)
	bonus.Size = UDim2.fromScale(0.84, 0.12)
	bonus.Font = Enum.Font.GothamBold
	bonus.Text = house.bonus
	bonus.TextColor3 = Color3.fromRGB(255, 244, 220)
	bonus.TextScaled = true
	bonus.Parent = card
	corner(bonus, 6)

	card.MouseButton1Click:Connect(function()
		if busy or player:GetAttribute("HouseId") then
			return
		end
		busy = true
		ChooseHouse:FireServer(id)
		task.delay(2, function()
			if not player:GetAttribute("HouseId") then
				busy = false
			end
		end)
	end)
end

local function refreshPicker()
	picker.Visible = player:GetAttribute("HouseId") == nil
end
player:GetAttributeChangedSignal("HouseId"):Connect(refreshPicker)
refreshPicker()

-- HUD --------------------------------------------------------------------------

local hud = Instance.new("Frame")
hud.Name = "HUD"
hud.Size = UDim2.fromScale(1, 1)
hud.BackgroundTransparency = 1
hud.Parent = gui

local top = Instance.new("Frame")
top.AnchorPoint = Vector2.new(0.5, 0)
top.Position = UDim2.fromScale(0.5, 0.02)
top.Size = UDim2.new(0.94, 0, 0, 74)
top.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
top.BackgroundTransparency = 0.28
top.BorderSizePixel = 0
top.Parent = hud
corner(top, 12)
stroke(top, Color3.fromRGB(196, 168, 96), 1)

local timerLabel = Instance.new("TextLabel")
timerLabel.BackgroundTransparency = 1
timerLabel.Position = UDim2.fromScale(0.04, 0.06)
timerLabel.Size = UDim2.fromScale(0.42, 0.42)
timerLabel.Font = Enum.Font.GothamBold
timerLabel.TextXAlignment = Enum.TextXAlignment.Left
timerLabel.Text = "8:00"
timerLabel.TextColor3 = Color3.fromRGB(240, 230, 210)
timerLabel.TextScaled = true
timerLabel.Parent = top

local nightLabel = Instance.new("TextLabel")
nightLabel.BackgroundTransparency = 1
nightLabel.Position = UDim2.fromScale(0.48, 0.08)
nightLabel.Size = UDim2.fromScale(0.48, 0.38)
nightLabel.Font = Enum.Font.Gotham
nightLabel.TextXAlignment = Enum.TextXAlignment.Right
nightLabel.Text = "Dusk"
nightLabel.TextColor3 = Color3.fromRGB(180, 190, 210)
nightLabel.TextScaled = true
nightLabel.Parent = top

local claimRow = Instance.new("Frame")
claimRow.BackgroundTransparency = 1
claimRow.Position = UDim2.fromScale(0.04, 0.52)
claimRow.Size = UDim2.fromScale(0.92, 0.4)
claimRow.Parent = top
local claimLayout = Instance.new("UIListLayout")
claimLayout.FillDirection = Enum.FillDirection.Horizontal
claimLayout.Padding = UDim.new(0.02, 0)
claimLayout.Parent = claimRow

local claimLabels = {}
for _, id in ipairs(Config.HouseOrder) do
	local house = Config.Houses[id]
	local chip = Instance.new("TextLabel")
	chip.BackgroundColor3 = house.color
	chip.BackgroundTransparency = 0.15
	chip.Size = UDim2.fromScale(0.235, 1)
	chip.Font = Enum.Font.GothamBold
	chip.Text = house.sigil .. " 0"
	chip.TextColor3 = house.ink
	chip.TextScaled = true
	chip.Parent = claimRow
	corner(chip, 6)
	claimLabels[id] = chip
end

local objective = Instance.new("TextLabel")
objective.AnchorPoint = Vector2.new(0.5, 0)
objective.Position = UDim2.new(0.5, 0, 0.02, 86)
objective.Size = UDim2.new(0.92, 0, 0, 28)
objective.BackgroundTransparency = 1
objective.Font = Enum.Font.GothamMedium
objective.Text = "Swear to a house."
objective.TextColor3 = Color3.fromRGB(236, 226, 206)
objective.TextStrokeTransparency = 0.4
objective.TextScaled = true
objective.Parent = hud

local healthBack = Instance.new("Frame")
healthBack.AnchorPoint = Vector2.new(0, 1)
healthBack.Position = UDim2.new(0, 16, 1, -18)
healthBack.Size = UDim2.fromOffset(240, 22)
healthBack.BackgroundColor3 = Color3.fromRGB(20, 16, 16)
healthBack.BorderSizePixel = 0
healthBack.Parent = hud
corner(healthBack, 6)

local healthFill = Instance.new("Frame")
healthFill.Size = UDim2.fromScale(1, 1)
healthFill.BackgroundColor3 = Color3.fromRGB(176, 48, 48)
healthFill.BorderSizePixel = 0
healthFill.Parent = healthBack
corner(healthFill, 6)

local healthText = Instance.new("TextLabel")
healthText.BackgroundTransparency = 1
healthText.Size = UDim2.fromScale(1, 1)
healthText.Font = Enum.Font.GothamBold
healthText.Text = "100"
healthText.TextColor3 = Color3.new(1, 1, 1)
healthText.TextScaled = true
healthText.ZIndex = 2
healthText.Parent = healthBack

local coinLabel = Instance.new("TextLabel")
coinLabel.AnchorPoint = Vector2.new(0, 1)
coinLabel.Position = UDim2.new(0, 16, 1, -46)
coinLabel.Size = UDim2.fromOffset(220, 24)
coinLabel.BackgroundTransparency = 1
coinLabel.Font = Enum.Font.GothamBold
coinLabel.TextXAlignment = Enum.TextXAlignment.Left
coinLabel.Text = "0 coins"
coinLabel.TextColor3 = Color3.fromRGB(232, 196, 96)
coinLabel.TextScaled = true
coinLabel.Parent = hud

local hint = Instance.new("TextLabel")
hint.AnchorPoint = Vector2.new(0.5, 1)
hint.Position = UDim2.new(0.5, 0, 1, -16)
hint.Size = UDim2.new(0.7, 0, 0, 22)
hint.BackgroundTransparency = 1
hint.Font = Enum.Font.Gotham
hint.Text = "Click strike    ·    Hold Q guard"
hint.TextColor3 = Color3.fromRGB(210, 210, 216)
hint.TextStrokeTransparency = 0.5
hint.TextScaled = true
hint.Parent = hud

local cross = Instance.new("Frame")
cross.AnchorPoint = Vector2.new(0.5, 0.5)
cross.Position = UDim2.fromScale(0.5, 0.5)
cross.Size = UDim2.fromOffset(8, 8)
cross.BackgroundColor3 = Color3.fromRGB(255, 244, 230)
cross.BackgroundTransparency = 0.25
cross.BorderSizePixel = 0
cross.Parent = hud
corner(cross, 8)

-- Minimap
local mapFrame = Instance.new("Frame")
mapFrame.AnchorPoint = Vector2.new(1, 0)
local cap = Instance.new("UISizeConstraint")
cap.MaxSize = Vector2.new(640, 74)
cap.Parent = top

mapFrame.Position = UDim2.new(1, -12, 0, 98)
mapFrame.Size = UDim2.fromOffset(168, 168)
mapFrame.BackgroundColor3 = Color3.fromRGB(18, 28, 22)
mapFrame.BackgroundTransparency = 0.2
mapFrame.BorderSizePixel = 0
mapFrame.Parent = hud
corner(mapFrame, 12)
stroke(mapFrame, Color3.fromRGB(180, 170, 130), 1)

local mapTitle = Instance.new("TextLabel")
mapTitle.BackgroundTransparency = 1
mapTitle.Size = UDim2.new(1, 0, 0, 18)
mapTitle.Font = Enum.Font.GothamBold
mapTitle.Text = "VAELMARK"
mapTitle.TextColor3 = Color3.fromRGB(220, 210, 180)
mapTitle.TextSize = 12
mapTitle.Parent = mapFrame

local dots = {}
local function makeDot(name, color, size)
	local dot = Instance.new("Frame")
	dot.Name = name
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Size = UDim2.fromOffset(size or 8, size or 8)
	dot.BackgroundColor3 = color
	dot.BorderSizePixel = 0
	dot.Parent = mapFrame
	corner(dot, size or 8)
	dots[name] = dot
	return dot
end

for _, info in ipairs(Config.Banners) do
	makeDot("Banner_" .. info.id, Color3.fromRGB(180, 180, 180), 10)
end
makeDot("Throne", Color3.fromRGB(255, 186, 70), 9)
makeDot("You", Color3.fromRGB(255, 255, 255), 8)

local function worldToMap(pos)
	local bounds = Config.MapBounds
	local x = (pos.X - bounds.minX) / (bounds.maxX - bounds.minX)
	local z = (pos.Z - bounds.minZ) / (bounds.maxZ - bounds.minZ)
	return math.clamp(x, 0.04, 0.96), math.clamp(z, 0.12, 0.96)
end

-- Toast
local toastLabel = Instance.new("TextLabel")
toastLabel.AnchorPoint = Vector2.new(0.5, 0)
toastLabel.Position = UDim2.fromScale(0.5, 0.2)
toastLabel.Size = UDim2.fromOffset(680, 48)
toastLabel.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
toastLabel.BackgroundTransparency = 1
toastLabel.Font = Enum.Font.Garamond
toastLabel.Text = ""
toastLabel.TextColor3 = Color3.fromRGB(244, 232, 206)
toastLabel.TextTransparency = 1
toastLabel.TextScaled = true
toastLabel.Parent = hud
corner(toastLabel, 10)

local toastToken = 0
local function showToast(text)
	toastToken += 1
	local token = toastToken
	toastLabel.Text = text
	toastLabel.TextTransparency = 0
	toastLabel.BackgroundTransparency = 0.28
	task.delay(4.2, function()
		if toastToken == token then
			toastLabel.TextTransparency = 1
			toastLabel.BackgroundTransparency = 1
		end
	end)
end

Toast.OnClientEvent:Connect(showToast)

HitFx.OnClientEvent:Connect(function(worldPos, amount)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(80, 36)
	billboard.AlwaysOnTop = true
	billboard.StudsOffset = Vector3.new(0, 0, 0)
	billboard.Adornee = nil
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Position = worldPos
	anchor.Parent = workspace
	billboard.Adornee = anchor
	billboard.Parent = anchor
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.Text = tostring(amount)
	label.TextColor3 = Color3.fromRGB(255, 220, 160)
	label.TextScaled = true
	label.Parent = billboard
	local rise = TweenService:Create(anchor, TweenInfo.new(0.6), { Position = worldPos + Vector3.new(0, 3, 0) })
	rise:Play()
	task.delay(0.6, function()
		anchor:Destroy()
	end)
end)

-- Mobile buttons
local touch = UserInputService.TouchEnabled
local swingButton, guardButton
if touch then
	swingButton = Instance.new("TextButton")
	swingButton.AnchorPoint = Vector2.new(1, 1)
	swingButton.Position = UDim2.new(1, -24, 1, -36)
	swingButton.Size = UDim2.fromOffset(92, 92)
	swingButton.BackgroundColor3 = Color3.fromRGB(150, 36, 36)
	swingButton.Font = Enum.Font.GothamBold
	swingButton.Text = "STRIKE"
	swingButton.TextColor3 = Color3.new(1, 1, 1)
	swingButton.TextScaled = true
	swingButton.Parent = hud
	corner(swingButton, 46)

	guardButton = Instance.new("TextButton")
	guardButton.AnchorPoint = Vector2.new(1, 1)
	guardButton.Position = UDim2.new(1, -130, 1, -48)
	guardButton.Size = UDim2.fromOffset(84, 84)
	guardButton.BackgroundColor3 = Color3.fromRGB(40, 48, 64)
	guardButton.Font = Enum.Font.GothamBold
	guardButton.Text = "GUARD"
	guardButton.TextColor3 = Color3.new(1, 1, 1)
	guardButton.TextScaled = true
	guardButton.Parent = hud
	corner(guardButton, 42)
	hint.Visible = false
end

-- Combat input ----------------------------------------------------------------

local lastLocalSwing = 0
local blocking = false

local function canFight()
	return player:GetAttribute("HouseId") ~= nil and picker.Visible == false
end

local function swing()
	if not canFight() then
		return
	end
	local now = os.clock()
	if now - lastLocalSwing < 0.5 then
		return
	end
	lastLocalSwing = now
	Swing:FireServer()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		local slash = Instance.new("Part")
		slash.Anchored = true
		slash.CanCollide = false
		slash.Material = Enum.Material.Neon
		slash.Color = Color3.fromRGB(255, 236, 210)
		slash.Size = Vector3.new(0.2, 3.2, 0.2)
		slash.CFrame = root.CFrame * CFrame.new(0.8, 1, -2.4) * CFrame.Angles(0, 0, math.rad(70))
		slash.Parent = workspace
		task.delay(0.12, function()
			slash:Destroy()
		end)
	end
end

local function setBlock(on)
	if blocking == on then
		return
	end
	blocking = on
	if canFight() then
		Block:FireServer(on)
	end
	cross.BackgroundColor3 = on and Color3.fromRGB(120, 180, 255) or Color3.fromRGB(255, 244, 230)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		swing()
	elseif input.KeyCode == Enum.KeyCode.Q then
		setBlock(true)
	elseif input.KeyCode == Enum.KeyCode.ButtonR2 then
		swing()
	elseif input.KeyCode == Enum.KeyCode.ButtonL2 then
		setBlock(true)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.ButtonL2 then
		setBlock(false)
	end
end)

if swingButton then
	swingButton.MouseButton1Click:Connect(swing)
end
if guardButton then
	guardButton.MouseButton1Down:Connect(function()
		setBlock(true)
	end)
	guardButton.MouseButton1Up:Connect(function()
		setBlock(false)
	end)
	guardButton.MouseLeave:Connect(function()
		setBlock(false)
	end)
end

local function equipSword()
	local character = player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local tool = character:FindFirstChildOfClass("Tool")
	if tool then
		return
	end
	local backpack = player:FindFirstChild("Backpack")
	tool = backpack and backpack:FindFirstChildOfClass("Tool")
	if tool then
		humanoid:EquipTool(tool)
	end
end

player.CharacterAdded:Connect(function()
	setBlock(false)
	task.delay(0.4, equipSword)
end)

-- HUD heartbeat ----------------------------------------------------------------

local function formatTime(seconds)
	seconds = math.max(0, math.floor(seconds + 0.5))
	local m = math.floor(seconds / 60)
	local s = seconds % 60
	return string.format("%d:%02d", m, s)
end

local function refreshHud()
	local houseId = player:GetAttribute("HouseId")
	hud.Visible = houseId ~= nil
	cross.Visible = houseId ~= nil

	local ends = matchFolder:GetAttribute("RoundEnds") or 0
	local remain = ends - workspace:GetServerTimeNow()
	local live = matchFolder:GetAttribute("RoundLive")
	if live == false then
		timerLabel.Text = "INTERMISSION"
	else
		timerLabel.Text = formatTime(remain)
	end

	local clock = Lighting.ClockTime
	local night = clock >= 18 or clock < 6
	nightLabel.Text = night and "Night — Frostholm cuts deeper" or "Day"
	nightLabel.TextColor3 = night and Color3.fromRGB(150, 196, 230) or Color3.fromRGB(230, 200, 140)

	local owned = 0
	for _, id in ipairs(Config.HouseOrder) do
		local n = matchFolder:GetAttribute("Claims_" .. id) or 0
		claimLabels[id].Text = Config.Houses[id].sigil .. " " .. tostring(n)
		if id == houseId then
			-- count banners below
		end
	end
	for _, info in ipairs(Config.Banners) do
		local owner = matchFolder:GetAttribute("Banner_" .. info.id) or "Neutral"
		local dot = dots["Banner_" .. info.id]
		local mx, my = worldToMap(info.position)
		dot.Position = UDim2.fromScale(mx, my)
		if owner ~= "Neutral" and Config.Houses[owner] then
			dot.BackgroundColor3 = Config.Houses[owner].color
			if owner == houseId then
				owned += 1
			end
		else
			dot.BackgroundColor3 = Color3.fromRGB(190, 190, 190)
		end
	end

	local tx, ty = worldToMap(Config.ThronePosition)
	dots.Throne.Position = UDim2.fromScale(tx, ty)

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root then
		local px, py = worldToMap(root.Position)
		dots.You.Position = UDim2.fromScale(px, py)
	end
	if humanoid then
		local ratio = math.clamp(humanoid.Health / math.max(1, humanoid.MaxHealth), 0, 1)
		healthFill.Size = UDim2.fromScale(ratio, 1)
		healthText.Text = tostring(math.ceil(humanoid.Health))
		if ratio < 0.35 then
			healthFill.BackgroundColor3 = Color3.fromRGB(210, 60, 50)
		else
			healthFill.BackgroundColor3 = Color3.fromRGB(176, 64, 58)
		end
	end

	local stats = player:FindFirstChild("leaderstats")
	local coins = stats and stats:FindFirstChild("Coins")
	coinLabel.Text = tostring(coins and coins.Value or 0) .. " coins"

	local winner = matchFolder:GetAttribute("Winner")
	if live == false and winner and winner ~= "" and Config.Houses[winner] then
		objective.Text = Config.Houses[winner].name .. " holds the realm."
	elseif not houseId then
		objective.Text = "Swear to a house."
	elseif owned >= Config.ThroneBannersNeeded then
		objective.Text = "You hold " .. owned .. " banners. Stand on the Cinder Seat."
	else
		objective.Text = "Raise banners (" .. owned .. "/" .. Config.ThroneBannersNeeded .. "). Rings are marked on the map."
	end

	local throneHouse = matchFolder:GetAttribute("ThroneHouse")
	local throneProgress = matchFolder:GetAttribute("ThroneProgress") or 0
	if throneHouse == houseId and throneProgress > 0.02 then
		objective.Text = "Holding the Cinder Seat… " .. tostring(math.floor(throneProgress * 100)) .. "%"
	end
end

task.spawn(function()
	while true do
		refreshHud()
		task.wait(0.15)
	end
end)

print("[Ashen Realm] Client ready.")
