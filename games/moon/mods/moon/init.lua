-- primitive-engine/init.lua
-- Entry point: loads sub-modules, creates global `moon` namespace, registers global-step hook to runtime scheduler

-- Dependency order: constants → util → materials → voxels → bonds → ports → islands → solvers → runtime

local modpath = minetest.get_modpath(minetest.get_current_modname())

-- -- Core constants and utilities (physics)
dofile(modpath .. "/constants.lua")
dofile(modpath .. "/util.lua")



-- -- Load resources
-- dofile(minetest.get_modpath("moon") .. "/resources.lua")

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

-- -- Register moon nodes required by cratermg
-- minetest.register_node("moon:regolith", {
--   description = "Moon Regolith",
--   tiles = {"default_dirt.png"},
--   groups = {cracky = 3, crumbly = 2},
--   sounds = default and default.node_sound_dirt_defaults and default.node_sound_dirt_defaults() or {},
-- })

dofile(cratermg.path..'/default.lua')

























-- Materials subsystem
materials = {}
materials.flags    = dofile(modpath .. "/materials/flags.lua")
materials.registry = dofile(modpath .. "/materials/registry.lua")
materials.reactions = dofile(modpath .. "/materials/reactions.lua")

-- Voxels subsystem
voxels = {}
voxels.metadata      = dofile(modpath .. "/voxels/metadata.lua")
voxels.serialization = dofile(modpath .. "/voxels/serialization.lua")

-- Bonds subsystem
bonds = {}
bonds.types    = dofile(modpath .. "/bonds/types.lua")
bonds.registry = dofile(modpath .. "/bonds/registry.lua")
bonds.api      = dofile(modpath .. "/bonds/api.lua")

-- Ports subsystem
ports = {}
ports.types    = dofile(modpath .. "/ports/types.lua")
ports.registry = dofile(modpath .. "/ports/registry.lua")
ports.api      = dofile(modpath .. "/ports/api.lua")

-- Islands subsystem
local islands = {}
islands.detector = dofile(modpath .. "/islands/detector.lua")
islands.queue    = dofile(modpath .. "/islands/queue.lua")

-- Solvers (make global so tick_scheduler can access them)
electrical    = dofile(modpath .. "/solvers/electrical.lua")
logic         = dofile(modpath .. "/solvers/logic.lua")
mechanical    = dofile(modpath .. "/solvers/mechanical.lua")
thermal       = dofile(modpath .. "/solvers/thermal.lua")
chemistry     = dofile(modpath .. "/solvers/chemistry.lua")
material_flow = dofile(modpath .. "/solvers/material_flow.lua")
rf            = dofile(modpath .. "/solvers/rf.lua")
mining        = dofile(modpath .. "/solvers/mining.lua")

-- Runtime
local runtime = {}
runtime.tick_scheduler = dofile(modpath .. "/runtime/tick_scheduler.lua")
runtime.profiler       = dofile(modpath .. "/runtime/profiler.lua")
runtime.debug_overlay  = dofile(modpath .. "/runtime/debug_overlay.lua")

-- Canonical moon namespace
moon = {
    MATERIAL   = materials.flags,
    BOND       = bonds.types,
    PORT       = ports.types,
    -- sub-modules for direct access
    materials  = materials.registry,
    bonds      = bonds.registry,
    ports      = ports.registry,
    islands    = islands,
}

-- Register globalstep hook to tick scheduler
minetest.register_globalstep(runtime.tick_scheduler.global_step)

-- Load debug commands (after moon namespace is created)
dofile(minetest.get_modpath("moon") .. "/commands/debug.lua")





-- Load the special physics nodes (wheels, electronics, etc)
dofile(minetest.get_modpath("moon") .. "/init_nodes.lua")




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

-- Set proper spawn position on surface
minetest.register_on_newplayer(function(player)
  local spawn_pos = {x = 0, y = 0, z = 0}
  
  -- Find surface level at spawn point
  for y = 50, -50, -1 do
    local node = minetest.get_node({x = 0, y = y, z = 0})
    if node.name ~= "air" then
      spawn_pos.y = y + 2  -- Spawn 2 blocks above surface
      break
    end
  end
  
  player:set_pos(spawn_pos)
end)

-- Also handle respawning
minetest.register_on_respawnplayer(function(player)
  local spawn_pos = {x = 0, y = 0, z = 0}
  
  -- Find surface level at spawn point
  for y = 50, -50, -1 do
    local node = minetest.get_node({x = 0, y = y, z = 0})
    if node.name ~= "air" then
      spawn_pos.y = y + 2  -- Spawn 2 blocks above surface
      break
    end
  end
  
  player:set_pos(spawn_pos)
  return true
end)

-- -- Auto-run wheel demo on startup for testing
-- minetest.register_on_mods_loaded(function()
--   minetest.after(2, function()  -- Wait 2 seconds after mods loaded
--     minetest.log("action", "[moon] Auto-running wheel demo...")
--     local demo_blueprints = dofile(minetest.get_modpath("moon") .. "/schematics/demo_blueprints.lua")
--     local spawn_pos = {x = 0, y = 1, z = 0}  -- Above spawn point
--     demo_blueprints.place_wheel_demo(spawn_pos)
--     minetest.log("action", "[moon] Auto wheel demo completed at " .. minetest.pos_to_string(spawn_pos))
--   end)
-- end)
-- Scan all saved ports/bonds and schedule every island once
minetest.after(3.5, function()
  local all = moon.islands.detector.scan_all()
  local now = minetest.get_gametime()
  for _, isl in pairs(all) do
    moon.islands.queue.push_or_update(isl, now - 0.001)  -- run next tick
  end
  minetest.log("action", ("[moon] Scheduled %d islands after world load"):format(#all))
end)

minetest.log("action", "[MOON MOD] Initialization complete!")

