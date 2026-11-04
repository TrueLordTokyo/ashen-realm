-- If the forest was not saved from Studio yet, grow it when the server starts.
local builder = require(game:GetService("ReplicatedStorage"):WaitForChild("MapBuilder"))
builder.build()
builder.startAmbience()
