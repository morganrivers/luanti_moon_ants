-- Moon Mod Initialization
minetest.log("action", "[MOON MOD] Initializing moon mod...")
local modname = minetest.get_current_modname()
local modpath = minetest.get_modpath(modname)
-- Load basic nodes first
dofile(minetest.get_modpath("moon") .. "/nodes.lua")

-- Apply gravity settings for lunar environment
dofile(minetest.get_modpath("moon") .. "/gravity.lua")

-- Load resources and energy systems BEFORE terrain generation
minetest.log("action", "[MOON MOD] Loading resources and energy systems...")
dofile(minetest.get_modpath("moon") .. "/resources.lua")
dofile(minetest.get_modpath("moon") .. "/energy.lua")

-- Load terrain generation (after resource definitions)
minetest.log("action", "[MOON MOD] Loading terrain generation...")
dofile(minetest.get_modpath("moon") .. "/terrain.lua")

-- Load map generation settings and decorations
dofile(minetest.get_modpath("moon") .. "/mapgen.lua")

-- Load nest AFTER terrain generation to ensure it's not overwritten
minetest.log("action", "[MOON MOD] Setting up initial nest...")
dofile(minetest.get_modpath("moon") .. "/nests.lua")

-- Load ant entities (after resources/energy systems)
minetest.log("action", "[MOON MOD] Loading ant entities...")
-- helpers first
dofile(modpath.."/util/table_extend.lua")

-- ant logic (order does not matter because entity.lua
-- pulls the modules when it runs)
dofile(modpath.."/ant/constants.lua")
dofile(modpath.."/ant/movement.lua")
dofile(modpath.."/ant/digging.lua")
dofile(modpath.."/ant/resource.lua")
dofile(modpath.."/ant/entity.lua")

-- Load environmental challenges
minetest.log("action", "[MOON MOD] Loading environmental challenges...")
dofile(minetest.get_modpath("moon") .. "/challenges.lua")

-- Load genetics and evolution system
minetest.log("action", "[MOON MOD] Loading genetics and evolution system...")
dofile(minetest.get_modpath("moon") .. "/genetics.lua")

-- Enable creative-mode digging for testing
minetest.override_item("", {
    tool_capabilities = {
        full_punch_interval = 0.1,
        max_drop_level = 3,
        groupcaps = {
            cracky = {times = {[1]=0.0, [2]=0.0, [3]=0.0}, uses=0, maxlevel=3},
            crumbly = {times = {[1]=0.0, [2]=0.0, [3]=0.0}, uses=0, maxlevel=3},
            snappy = {times = {[1]=0.0, [2]=0.0, [3]=0.0}, uses=0, maxlevel=3},
            choppy = {times = {[1]=0.0, [2]=0.0, [3]=0.0}, uses=0, maxlevel=3},
            oddly_breakable_by_hand = {times = {[1]=0.0, [2]=0.0, [3]=0.0}, uses=0, maxlevel=3},
        },
        damage_groups = {fleshy=1},
    }
})

-- Register some additional helpful commands
minetest.register_chatcommand("deployprinter", {
    description = "Deploy an Electroplating Fabricator at your position",
    func = function(name, param)
        local player = minetest.get_player_by_name(name)
        if not player then return false, "Player not found" end
        
        local pos = player:get_pos()
        pos.y = math.floor(pos.y)
        
        minetest.set_node(pos, {name = "moon:fabricator"})
        return true, "Electroplating Fabricator deployed at " .. minetest.pos_to_string(pos)
    end,
})

minetest.register_chatcommand("deploysolar", {
    description = "Deploy a Solar Array at your position",
    func = function(name, param)
        local player = minetest.get_player_by_name(name)
        if not player then return false, "Player not found" end
        
        local pos = player:get_pos()
        pos.y = math.floor(pos.y)
        
        minetest.set_node(pos, {name = "moon:solar_array"})
        minetest.get_node_timer(pos):start(10)
        return true, "Solar Array deployed at " .. minetest.pos_to_string(pos)
    end,
})

minetest.register_chatcommand("deployhub", {
    description = "Deploy a Fabrication Hub at your position",
    func = function(name, param)
        local player = minetest.get_player_by_name(name)
        if not player then return false, "Player not found" end
        
        local pos = player:get_pos()
        pos.y = math.floor(pos.y)
        
        minetest.set_node(pos, {name = "moon:nest_core"})
        return true, "Fabrication Hub deployed at " .. minetest.pos_to_string(pos)
    end,
})

minetest.log("action", "[MOON MOD] Initialization complete!")
