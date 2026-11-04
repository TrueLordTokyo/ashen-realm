-- Runs when the place is opened in Studio, so the forest exists before you press Play.
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end

local builder = require(game:GetService("ReplicatedStorage"):WaitForChild("MapBuilder"))
builder.build()
