-- Smooth terrain only. No blocky ground.
-- Run this in edit mode so Studio keeps it:
--   require(game.ReplicatedStorage.Forest).grow()

local Lighting = game:GetService("Lighting")
local InsertService = game:GetService("InsertService")
local AssetService = game:GetService("AssetService")

local Forest = {}

local SEED = 90411
local VOXEL = 4
local MIN_X, MAX_X = -2560, 2560
local MIN_Z, MAX_Z = -2560, 2560
local MIN_Y, MAX_Y = 0, 160
local CHUNK = 128
local SEA = 22
local LAKE = 34

-- Free Creator Store models. Loaded if Roblox allows it. Never used as the ground.
local SCENERY_IDS = {
	6432306802, -- Forest Pack (trees, bushes, rocks, stumps)
}

local PATH = {
	Vector3.new(-1700, 0, -400),
	Vector3.new(-1000, 0, -80),
	Vector3.new(-400, 0, 80),
	Vector3.new(200, 0, 220),
	Vector3.new(900, 0, 420),
	Vector3.new(1600, 0, 680),
}

local function smoothstep(a, b, x)
	local t = math.clamp((x - a) / (b - a), 0, 1)
	return t * t * (3 - 2 * t)
end

local function fade(t)
	return t * t * t * (t * (t * 6 - 15) + 10)
end

local function hash2(ix, iz)
	local n = math.sin(ix * 127.1 + iz * 311.7 + SEED * 0.01) * 43758.5453
	return n - math.floor(n)
end

local function noise(x, z)
	local x0 = math.floor(x)
	local z0 = math.floor(z)
	local tx = fade(x - x0)
	local tz = fade(z - z0)
	local v00 = hash2(x0, z0)
	local v10 = hash2(x0 + 1, z0)
	local v01 = hash2(x0, z0 + 1)
	local v11 = hash2(x0 + 1, z0 + 1)
	return v00 + (v10 - v00) * tx + (v01 + (v11 - v01) * tx - (v00 + (v10 - v00) * tx)) * tz
end

local function distToPath(x, z)
	local best = 1e9
	for i = 1, #PATH - 1 do
		local a, b = PATH[i], PATH[i + 1]
		local abx, abz = b.X - a.X, b.Z - a.Z
		local apx, apz = x - a.X, z - a.Z
		local ab2 = abx * abx + abz * abz
		local t = ab2 > 0 and math.clamp((apx * abx + apz * abz) / ab2, 0, 1) or 0
		local dx = x - (a.X + abx * t)
		local dz = z - (a.Z + abz * t)
		best = math.min(best, math.sqrt(dx * dx + dz * dz))
	end
	return best
end

local function disk(x, z, cx, cz, rx, rz)
	local dx = (x - cx) / rx
	local dz = (z - cz) / rz
	local d = math.sqrt(dx * dx + dz * dz)
	return math.clamp(1 - d, 0, 1), d
end

local function segmentDist(x, z, ax, az, bx, bz)
	local abx, abz = bx - ax, bz - az
	local apx, apz = x - ax, z - az
	local ab2 = abx * abx + abz * abz
	local t = ab2 > 0 and math.clamp((apx * abx + apz * abz) / ab2, 0, 1) or 0
	local dx = x - (ax + abx * t)
	local dz = z - (az + abz * t)
	return math.sqrt(dx * dx + dz * dz), t
end

local function baseShape(x, z)
	local n = noise(x * 0.0021, z * 0.0021) * 0.58 + noise(x * 0.0054 + 2, z * 0.0054) * 0.42
	local h = 36 + n * 18
	local peak = math.exp(-((x + 1700) ^ 2) / 70000) * math.exp(-((z + 400) ^ 2) / 52000)
	h += peak * 70
	local drop = smoothstep(1760, 2200, x)
	h = h * (1 - drop) + (SEA - 14) * drop
	return h, drop, n, peak
end

local function column(x, z)
	local h, drop, n, peak = baseShape(x, z)

	local open = disk(x, z, -400, 80, 170, 140)
	local heath = disk(x, z, -1100, -1200, 340, 240)
	local hollow = disk(x, z, -1500, 980, 200, 160)
	local marsh = disk(x, z, 180, -1680, 420, 300)
	local lake, lakeD = disk(x, z, -180, 1560, 230, 190)
	local isleInLake = disk(x, z, -180, 1560, 40, 32)
	local cove = disk(x, z, 1980, 780, 200, 140)
	local salt = disk(x, z, 2360, -180, 110, 86)
	local riverD = segmentDist(x, z, -2560, -1880, -1680, -2560)

	h -= hollow * 12
	if heath > 0 then
		h = h * (1 - heath * 0.45) + 32 * (heath * 0.45)
	end
	if open > 0 then
		h = h * (1 - open * 0.35) + 30 * (open * 0.35)
	end

	local ravineD, ravineT = segmentDist(x, z, -800, -640, 1760, -90)
	local inRavine = ravineD < 34
	if inRavine then
		local u = 1 - ravineD / 34
		local floorH = 42 - smoothstep(1520, 1760, x) * 26
		h -= u * u * math.max(0, h - floorH)
	end

	if lakeD < 1 and isleInLake <= 0 then
		h = math.min(h, 20 + (1 - (1 - lakeD)) * 6)
	elseif isleInLake > 0 then
		h = math.max(h, LAKE + 2 + isleInLake * 10)
	end

	if marsh > 0.15 then
		h = h * (1 - marsh) + (SEA + 1.5) * marsh
	end

	if cove > 0 then
		h -= cove * cove * 16
	end

	if salt > 0 then
		h = math.max(h, (SEA - 4) + salt * salt * 32)
	end

	if riverD < 96 then
		local u = 1 - riverD / 96
		local bed = 14 + (1 - u) * 12
		h = h * (1 - u) + bed * u
	end

	local pathD = distToPath(x, z)
	if pathD < 10 and x < 1800 and lakeD > 1 and marsh < 0.4 and riverD > 40 then
		h -= (1 - pathD / 10) * 1.1
	end

	h = math.clamp(h, 3, 148)

	local water = nil
	if lakeD < 0.98 and isleInLake <= 0 then
		water = LAKE
		if h > LAKE - 1 then
			h = LAKE - 3
		end
	end
	if inRavine and ravineD < 10 and ravineT < 0.92 then
		water = math.max(water or 0, h + 2.2)
	end
	if riverD < 36 then
		h = math.min(h, 15)
		water = math.max(water or 0, 26)
	end
	if marsh > 0.4 and noise(x * 0.018, z * 0.018) > 0.52 then
		h = SEA + 0.4
		water = SEA + 2.6
	end
	if x > 1980 and h < SEA then
		water = math.max(water or 0, SEA)
	end

	local eastH = baseShape(x + 18, z)
	local southH = baseShape(x, z + 18)
	local slope = math.abs(eastH - baseShape(x, z)) + math.abs(southH - baseShape(x, z))
	local ravineWall = inRavine and ravineD > 8 and ravineD < 30

	local mat = Enum.Material.Grass
	if riverD < 58 or marsh > 0.25 or (inRavine and ravineD < 12) or (lakeD < 1.15 and isleInLake <= 0) then
		mat = Enum.Material.Mud
	elseif salt > 0.15 and h < SEA + 6 then
		mat = Enum.Material.Sand
	elseif cove > 0.25 or (drop > 0.45 and h < SEA + 6) then
		mat = Enum.Material.Sand
	elseif peak > 0.35 or slope > 14 or ravineWall or (drop > 0.25 and drop < 0.85 and slope > 6) then
		mat = Enum.Material.Rock
	elseif pathD < 6 and x < 1800 then
		mat = Enum.Material.Mud
	elseif open < 0.2 and heath < 0.2 and (hollow > 0.15 or n > 0.3) then
		mat = Enum.Material.LeafyGrass
	end

	local trees = 0.96
	trees -= open * 1.2
	trees -= heath * 0.5
	trees -= marsh * 0.9
	trees += hollow * 0.25
	trees -= smoothstep(1760, 2200, x) * 0.95
	if lakeD < 1 or riverD < 42 or (inRavine and ravineD < 12) or pathD < 8 then
		trees -= 0.7
	end
	if salt > 0.4 then
		trees = math.max(trees, 0.25)
	end
	trees = math.clamp(trees, 0, 1)
	return h, water, mat, trees, open
end

local function applyLook()
	Lighting.ClockTime = 16.7
	Lighting.GeographicLatitude = 38
	Lighting.Brightness = 2.15
	Lighting.Ambient = Color3.fromRGB(78, 88, 80)
	Lighting.OutdoorAmbient = Color3.fromRGB(168, 176, 168)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 0.65
	Lighting.GlobalShadows = true
	Lighting.FogColor = Color3.fromRGB(186, 196, 188)
	Lighting.FogStart = 120
	Lighting.FogEnd = 2400
	pcall(function()
		Lighting.Technology = Enum.Technology.Future
	end)
	pcall(function()
		if Lighting.Technology ~= Enum.Technology.Future then
			Lighting.Technology = Enum.Technology.ShadowMap
		end
	end)

	local function fx(className, name)
		local inst = Lighting:FindFirstChild(name)
		if not inst then
			inst = Instance.new(className)
			inst.Name = name
			inst.Parent = Lighting
		end
		return inst
	end

	local atmo = fx("Atmosphere", "ForestAir")
	atmo.Density = 0.32
	atmo.Offset = 0.2
	atmo.Color = Color3.fromRGB(198, 206, 198)
	atmo.Decay = Color3.fromRGB(110, 122, 108)
	atmo.Glare = 0.18
	atmo.Haze = 1.4

	local grade = fx("ColorCorrectionEffect", "ForestGrade")
	grade.Saturation = -0.06
	grade.Contrast = 0.08
	grade.Brightness = 0.02
	grade.TintColor = Color3.fromRGB(214, 222, 208)

	local bloom = fx("BloomEffect", "ForestBloom")
	bloom.Intensity = 0.35
	bloom.Size = 20
	bloom.Threshold = 1.05

	local rays = fx("SunRaysEffect", "ForestRays")
	rays.Intensity = 0.08
	rays.Spread = 0.85

	local terrain = workspace.Terrain
	terrain.WaterColor = Color3.fromRGB(52, 92, 84)
	terrain.WaterReflectance = 0.45
	terrain.WaterTransparency = 0.15
	terrain.WaterWaveSize = 0.08
	terrain.WaterWaveSpeed = 5
	pcall(function()
		terrain.Decoration = true
		terrain.GrassLength = 0.85
	end)
	workspace.GlobalWind = Vector3.new(10, 0, 4)

	local colors = {
		Grass = Color3.fromRGB(62, 112, 52),
		LeafyGrass = Color3.fromRGB(42, 86, 40),
		Mud = Color3.fromRGB(78, 62, 44),
		Ground = Color3.fromRGB(92, 74, 48),
		Rock = Color3.fromRGB(96, 100, 94),
		Slate = Color3.fromRGB(82, 88, 84),
		Sand = Color3.fromRGB(128, 122, 100),
		Water = Color3.fromRGB(52, 92, 84),
	}
	for name, color in pairs(colors) do
		pcall(function()
			terrain:SetMaterialColor(Enum.Material[name], color)
		end)
	end

	local clouds = terrain:FindFirstChild("ForestClouds")
	if not clouds then
		clouds = Instance.new("Clouds")
		clouds.Name = "ForestClouds"
		clouds.Parent = terrain
	end
	clouds.Cover = 0.72
	clouds.Density = 0.55
	clouds.Color = Color3.fromRGB(230, 232, 228)
end

local function writeLand()
	local terrain = workspace.Terrain
	terrain:Clear()
	applyLook()

	local steps = (MAX_X - MIN_X) / CHUNK
	local n = 0
	for x0 = MIN_X, MAX_X - CHUNK, CHUNK do
		for z0 = MIN_Z, MAX_Z - CHUNK, CHUNK do
			local region = Region3.new(
				Vector3.new(x0, MIN_Y, z0),
				Vector3.new(x0 + CHUNK, MAX_Y, z0 + CHUNK)
			):ExpandToGrid(VOXEL)
			local size = region.Size / VOXEL
			local origin = region.CFrame.Position - region.Size / 2
			local materials, occupancy = {}, {}
			for ix = 1, size.X do
				materials[ix] = {}
				occupancy[ix] = {}
				for iy = 1, size.Y do
					materials[ix][iy] = {}
					occupancy[ix][iy] = table.create(size.Z, 0)
					for iz = 1, size.Z do
						materials[ix][iy][iz] = Enum.Material.Air
					end
				end
			end

			for ix = 1, size.X do
				for iz = 1, size.Z do
					local wx = origin.X + (ix - 0.5) * VOXEL
					local wz = origin.Z + (iz - 0.5) * VOXEL
					local h, water, topMat = column(wx, wz)
					for iy = 1, size.Y do
						local wy = origin.Y + (iy - 1) * VOXEL
						if wy + VOXEL <= h - VOXEL then
							materials[ix][iy][iz] = (wy < h - 16) and Enum.Material.Rock or Enum.Material.Ground
							occupancy[ix][iy][iz] = 1
						elseif wy < h then
							materials[ix][iy][iz] = topMat
							occupancy[ix][iy][iz] = math.clamp((h - wy) / VOXEL, 0.2, 1)
						elseif water and wy < water then
							materials[ix][iy][iz] = Enum.Material.Water
							occupancy[ix][iy][iz] = 1
						end
					end
				end
			end

			terrain:WriteVoxels(region, VOXEL, materials, occupancy)
			n += 1
			if z0 == MIN_Z then
				print(string.format("[Forest] Land %d / %d", (x0 - MIN_X) / CHUNK + 1, steps))
			end
			task.wait()
		end
	end
end

local function groundAt(x, z, minSlope)
	local hit = workspace:Raycast(Vector3.new(x, 900, z), Vector3.new(0, -1200, 0))
	if not hit or hit.Instance ~= workspace.Terrain then
		return nil
	end
	if hit.Material == Enum.Material.Water or hit.Normal.Y < (minSlope or 0.78) then
		return nil
	end
	return hit.Position, hit.Material
end

local function collectTemplates(root, into)
	for _, child in ipairs(root:GetChildren()) do
		if child:IsA("Model") then
			local meshes = 0
			for _, d in ipairs(child:GetDescendants()) do
				if d:IsA("MeshPart") or d:IsA("SpecialMesh") then
					meshes += 1
				end
			end
			if meshes > 0 then
				table.insert(into, child)
			else
				collectTemplates(child, into)
			end
		elseif child:IsA("Folder") then
			collectTemplates(child, into)
		end
	end
end

local function loadScenery()
	local templates = {}
	for _, id in ipairs(SCENERY_IDS) do
		local loaded
		local ok, result = pcall(function()
			return InsertService:LoadAsset(id)
		end)
		if ok then
			loaded = result
		else
			ok, result = pcall(function()
				return AssetService:LoadAssetAsync(id)
			end)
			if ok then
				loaded = result
			else
				warn("[Forest] Could not load scenery " .. id .. ": " .. tostring(result))
			end
		end
		if loaded then
			collectTemplates(loaded, templates)
			loaded.Parent = game:GetService("ServerStorage")
			print("[Forest] Loaded scenery asset " .. id .. " (" .. #templates .. " models)")
		end
	end
	return templates
end

local function scatter(templates, rng)
	if #templates == 0 then
		warn("[Forest] No tree meshes loaded. The grass is real terrain. Insert a tree pack from Toolbox, put the models in ServerStorage, and run grow() again.")
		return 0
	end
	local folder = workspace:FindFirstChild("ForestScenery")
	if folder then
		folder:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "ForestScenery"
	folder.Parent = workspace

	local placed = 0
	local tries = 0
	while placed < 1500 and tries < 9000 do
		tries += 1
		local x = rng:NextNumber(-2400, 1900)
		local z = rng:NextNumber(-2400, 2400)
		local _, _, _, trees = column(x, z)
		if trees > 0.18 and rng:NextNumber() < trees then
			local pos = groundAt(x, z, 0.86)
			if pos and pos.Y > SEA + 2 then
				local template = templates[rng:NextInteger(1, #templates)]
				local clone = template:Clone()
				clone.Parent = folder
				pcall(function()
					clone:ScaleTo(rng:NextNumber(0.8, 1.35))
				end)
				clone:PivotTo(CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
				local boundsCF, boundsSize = clone:GetBoundingBox()
				local bottom = boundsCF.Position.Y - boundsSize.Y / 2
				local planted = pos.Y
				for _, off in ipairs({
					Vector3.new(7, 0, 0),
					Vector3.new(-7, 0, 0),
					Vector3.new(0, 0, 7),
					Vector3.new(0, 0, -7),
				}) do
					local near = groundAt(pos.X + off.X, pos.Z + off.Z, 0.5)
					if near then
						planted = math.min(planted, near.Y)
					end
				end
				local sink = math.clamp(boundsSize.Y * 0.07, 1.5, 8)
				if boundsSize.Y > 20 then
					sink = math.max(sink, 4.5)
				end
				clone:PivotTo(clone:GetPivot() + Vector3.new(0, planted - bottom - sink, 0))
				placed += 1
				if placed % 20 == 0 then
					task.wait()
				end
			end
		end
	end
	return placed
end

local function addSpawn()
	local old = workspace:FindFirstChild("ForestSpawn")
	if old then
		old:Destroy()
	end
	local pos = groundAt(-400, 80) or Vector3.new(-400, 40, 80)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "ForestSpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.CFrame = CFrame.new(pos + Vector3.new(0, 4, 0))
	spawn.Parent = workspace
end

local function landmarks(terrain, rng)
	for _ = 1, 18 do
		local x = -1700 + rng:NextNumber(-110, 110)
		local z = -400 + rng:NextNumber(-90, 90)
		local pos = groundAt(x, z)
		if pos then
			terrain:FillBall(pos + Vector3.new(0, rng:NextNumber(0, 4), 0), rng:NextNumber(6, 14), Enum.Material.Rock)
		end
	end

	for _ = 1, 30 do
		local x = rng:NextNumber(1900, 2480)
		local z = rng:NextNumber(-2200, 2200)
		local pos = groundAt(x, z)
		if pos then
			terrain:FillBall(pos + Vector3.new(0, rng:NextNumber(0, 6), 0), rng:NextNumber(7, 16), Enum.Material.Rock)
		elseif x > 2100 then
			terrain:FillBall(Vector3.new(x, SEA + 2, z), rng:NextNumber(8, 18), Enum.Material.Rock)
		end
	end

	terrain:FillBlock(CFrame.new(1688, 28, -86), Vector3.new(14, 28, 12), Enum.Material.Water)
	terrain:FillBall(Vector3.new(1755, 16, -78), 18, Enum.Material.Water)
end

function Forest.grow()
	print("[Forest] Wider map, denser forest. Stay in edit mode. This takes several minutes.")
	local base = workspace:FindFirstChild("Baseplate")
	if base then
		base:Destroy()
	end
	local oldParts = workspace:FindFirstChild("Drenchwood")
	if oldParts then
		oldParts:Destroy()
	end

	writeLand()

	local rng = Random.new(SEED)
	local terrain = workspace.Terrain
	landmarks(terrain, rng)

	local templates = loadScenery()
	local trees = scatter(templates, rng)
	addSpawn()

	local cam = workspace.CurrentCamera
	if cam then
		cam.CFrame = CFrame.lookAt(Vector3.new(-1900, 145, -220), Vector3.new(-400, 36, 80))
	end

	print("[Forest] Done. File > Save, then Play.")
	print("[Forest] Ashmere meadow is the spawn. Highwatch peak is northwest.")
	print("[Forest] Stillwater lake is north, with an island. The Drown marsh is south.")
	print("[Forest] The Cut is the ravine. It falls toward the east cliffs.")
	print("[Forest] A river cuts the southwest corner. Greycove is the beach. Trees: " .. tostring(trees))
	return true
end

return Forest
