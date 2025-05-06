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
-- dofile(minetest.get_modpath("moon") .. "/mapgen.lua")










--[[
    Crater MG - Crater Map Generator for Minetest
    (c) Pierre-Yves Rollo

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published
    by the Free Software Foundation, either version 2.1 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
--]]

cratermg = {}

cratermg.name = minetest.get_current_modname()
cratermg.path = minetest.get_modpath(minetest.get_current_modname())

cratermg.materials = {}
cratermg.noises = {}

cratermg.profile = dofile(cratermg.path..'/profile.lua')

dofile(cratermg.path..'/functions.lua')
dofile(cratermg.path..'/config.lua')
-- dofile(cratermg.path..'/oregen.lua')
dofile(cratermg.path..'/mapgen.lua')

dofile(cratermg.path..'/default.lua')


























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

