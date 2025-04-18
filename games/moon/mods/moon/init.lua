-- Moon Mod Initialization
minetest.log("action", "[MOON MOD] Initializing moon mod...")

-- Load custom nodes (e.g., regolith)
dofile(minetest.get_modpath("moon") .. "/nodes.lua")

-- Load map generation settings and decorations
dofile(minetest.get_modpath("moon") .. "/mapgen.lua")

-- Apply gravity settings for lunar environment
dofile(minetest.get_modpath("moon") .. "/gravity.lua")

dofile(minetest.get_modpath("cratermg") .. "/mapgen.lua")

-- Load ant entities
dofile(minetest.get_modpath("moon") .. "/ant.lua")
