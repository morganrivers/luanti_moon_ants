-- primitive-engine/init.lua
-- Entry point: loads sub-modules, creates global `moon` namespace, registers global-step hook to runtime scheduler

-- Dependency order: constants → util → materials → voxels → bonds → ports → islands → solvers → runtime

local modpath = minetest.get_modpath(minetest.get_current_modname())

-- Core constants and utilities
dofile(modpath .. "/constants.lua")
dofile(modpath .. "/util.lua")

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

























-- Materials subsystem
local materials = {}
materials.flags    = dofile(modpath .. "/materials/flags.lua")
materials.registry = dofile(modpath .. "/materials/registry.lua")
materials.reactions = dofile(modpath .. "/materials/reactions.lua")

-- Voxels subsystem
local voxels = {}
voxels.metadata      = dofile(modpath .. "/voxels/metadata.lua")
voxels.serialization = dofile(modpath .. "/voxels/serialization.lua")

-- Bonds subsystem
local bonds = {}
bonds.types    = dofile(modpath .. "/bonds/types.lua")
bonds.registry = dofile(modpath .. "/bonds/registry.lua")
bonds.api      = dofile(modpath .. "/bonds/api.lua")

-- Ports subsystem
local ports = {}
ports.types    = dofile(modpath .. "/ports/types.lua")
ports.registry = dofile(modpath .. "/ports/registry.lua")
ports.api      = dofile(modpath .. "/ports/api.lua")

-- Islands subsystem
local islands = {}
islands.detector = dofile(modpath .. "/islands/detector.lua")
islands.queue    = dofile(modpath .. "/islands/queue.lua")

-- Solvers
local solvers = {}
solvers.electrical    = dofile(modpath .. "/solvers/electrical.lua")
solvers.logic         = dofile(modpath .. "/solvers/logic.lua")
solvers.mechanical    = dofile(modpath .. "/solvers/mechanical.lua")
solvers.thermal       = dofile(modpath .. "/solvers/thermal.lua")
solvers.chemistry     = dofile(modpath .. "/solvers/chemistry.lua")
solvers.material_flow = dofile(modpath .. "/solvers/material_flow.lua")
solvers.rf            = dofile(modpath .. "/solvers/rf.lua")
solvers.mining        = dofile(modpath .. "/solvers/mining.lua")

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
}

-- Register globalstep hook to tick scheduler
minetest.register_globalstep(runtime.tick_scheduler.global_step)

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
