-- primitive-engine/init.lua
-- Entry point: loads sub-modules, creates global `moon` namespace, registers global-step hook to runtime scheduler

-- Dependency order: constants → util → materials → voxels → bonds → ports → islands → solvers → runtime

local modpath = minetest.get_modpath(minetest.get_current_modname())

-- Core constants and utilities
dofile(modpath.."/constants.lua")
dofile(modpath.."/util.lua")

-- Materials subsystem
local materials = {}
materials.flags    = dofile(modpath.."/materials/flags.lua")
materials.registry = dofile(modpath.."/materials/registry.lua")
materials.reactions = dofile(modpath.."/materials/reactions.lua")

-- Voxels subsystem
local voxels = {}
voxels.metadata      = dofile(modpath.."/voxels/metadata.lua")
voxels.serialization = dofile(modpath.."/voxels/serialization.lua")

-- Bonds subsystem
local bonds = {}
bonds.types    = dofile(modpath.."/bonds/types.lua")
bonds.registry = dofile(modpath.."/bonds/registry.lua")
bonds.api      = dofile(modpath.."/bonds/api.lua")

-- Ports subsystem
local ports = {}
ports.types    = dofile(modpath.."/ports/types.lua")
ports.registry = dofile(modpath.."/ports/registry.lua")
ports.api      = dofile(modpath.."/ports/api.lua")

-- Islands subsystem
local islands = {}
islands.detector = dofile(modpath.."/islands/detector.lua")
islands.queue    = dofile(modpath.."/islands/queue.lua")

-- Solvers
local solvers = {}
solvers.electrical    = dofile(modpath.."/solvers/electrical.lua")
solvers.logic         = dofile(modpath.."/solvers/logic.lua")
solvers.mechanical    = dofile(modpath.."/solvers/mechanical.lua")
solvers.thermal       = dofile(modpath.."/solvers/thermal.lua")
solvers.chemistry     = dofile(modpath.."/solvers/chemistry.lua")
solvers.material_flow = dofile(modpath.."/solvers/material_flow.lua")
solvers.rf            = dofile(modpath.."/solvers/rf.lua")
solvers.mining        = dofile(modpath.."/solvers/mining.lua")

-- Runtime
local runtime = {}
runtime.tick_scheduler = dofile(modpath.."/runtime/tick_scheduler.lua")
runtime.profiler       = dofile(modpath.."/runtime/profiler.lua")
runtime.debug_overlay  = dofile(modpath.."/runtime/debug_overlay.lua")

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
