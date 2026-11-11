--!strict
-- ServerScriptService/Server/init.server.luau
-- Generates the full detailed Prop Hunt Map ("Grand Warehouse, Office & Arcade Plaza") on startup.

local MapBuilder = require(script:WaitForChild("MapBuilder"))

MapBuilder.Generate()
