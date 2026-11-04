-- Ashen Realm
-- Edit houses, damage, round length, and map points here.
-- This is an original throne-war. Do not rename houses to copyrighted
-- Game of Thrones names if you plan to publish on Roblox.

local Config = {}

Config.RoundLength = 60 * 8
Config.Intermission = 8
Config.ClaimsToWin = 3
Config.BannerCaptureTime = 6
Config.ThroneChannelTime = 7
Config.ThroneBannersNeeded = 2
Config.SwordDamage = 24
Config.RuneDamage = 36
Config.SwordRange = 8
Config.SwordCooldown = 0.55
Config.RuneCost = 45
Config.PlayerKillCoins = 12
Config.RaiderKillCoins = 8
Config.GoldmereBonusCoins = 8
Config.ClaimCoins = 20
Config.RespawnTime = 5
Config.SpawnShield = 4
Config.ColdZ = -205
Config.ColdDamage = 6
Config.FrostholmNightBonus = 1.25
Config.TideholmSpeed = 20
Config.BaseSpeed = 16

Config.HouseOrder = { "Frostholm", "Goldmere", "Wyrmreach", "Tideholm" }

Config.Houses = {
	Frostholm = {
		id = "Frostholm",
		name = "House Frostholm",
		motto = "The Pale Does Not Yield",
		blurb = "Wardens of the Pale Wall. After dusk their steel bites harder, and the cold beyond the wall heals them.",
		bonus = "Night damage and they thrive in the snow.",
		teamColor = "Cyan",
		color = Color3.fromRGB(126, 206, 224),
		accent = Color3.fromRGB(232, 246, 252),
		ink = Color3.fromRGB(12, 32, 40),
		sigil = "HART",
	},
	Goldmere = {
		id = "Goldmere",
		name = "House Goldmere",
		motto = "Coin Outlives Kings",
		blurb = "The vault city. Every rival they drop pays more, and the smith sells them power sooner.",
		bonus = "Extra coins on every kill.",
		teamColor = "Bright yellow",
		color = Color3.fromRGB(224, 176, 62),
		accent = Color3.fromRGB(92, 18, 24),
		ink = Color3.fromRGB(42, 24, 8),
		sigil = "SCALE",
	},
	Wyrmreach = {
		id = "Wyrmreach",
		name = "House Wyrmreach",
		motto = "Fire Remembers",
		blurb = "Exiles of the wyrm. Dragonfire rolls off them, and their swords are heavier.",
		bonus = "Immune to dragonfire. Stronger blade.",
		teamColor = "Really red",
		color = Color3.fromRGB(168, 42, 42),
		accent = Color3.fromRGB(28, 18, 22),
		ink = Color3.fromRGB(255, 228, 220),
		sigil = "WYRM",
	},
	Tideholm = {
		id = "Tideholm",
		name = "House Tideholm",
		motto = "No Shore Holds Us",
		blurb = "Storm sailors. First to the banner, first off the throne steps.",
		bonus = "Faster on foot.",
		teamColor = "Bright blue",
		color = Color3.fromRGB(46, 118, 168),
		accent = Color3.fromRGB(216, 232, 238),
		ink = Color3.fromRGB(240, 248, 252),
		sigil = "WAVE",
	},
}

Config.Banners = {
	{ id = "East", label = "East Banner", position = Vector3.new(120, 0, 12) },
	{ id = "West", label = "West Banner", position = Vector3.new(-120, 0, 12) },
	{ id = "Pale", label = "Pale Banner", position = Vector3.new(0, 0, -155) },
}

Config.ThronePosition = Vector3.new(0, 0, -78)
Config.Camps = {
	Frostholm = Vector3.new(0, 0, -185),
	Goldmere = Vector3.new(150, 0, 78),
	Tideholm = Vector3.new(-150, 0, 78),
	Wyrmreach = Vector3.new(10, 0, 158),
}
Config.Lobby = Vector3.new(0, 0, 88)
Config.SafeCenter = Vector3.new(0, 8, 88)
Config.SafeHalf = Vector3.new(36, 24, 28)

Config.MapBounds = { minX = -230, maxX = 230, minZ = -270, maxZ = 200 }

Config.RaiderSpawns = {
	Vector3.new(96, 0, -90),
	Vector3.new(-96, 0, -90),
	Vector3.new(70, 0, 120),
	Vector3.new(-80, 0, 48),
	Vector3.new(36, 0, -168),
	Vector3.new(-30, 0, 175),
}

function Config.getHouse(id)
	return Config.Houses[id]
end

function Config.teamName(id)
	return "House " .. id
end

function Config.inSafe(position)
	local c = Config.SafeCenter
	local h = Config.SafeHalf
	return math.abs(position.X - c.X) <= h.X
		and math.abs(position.Y - c.Y) <= h.Y
		and math.abs(position.Z - c.Z) <= h.Z
end

return Config
