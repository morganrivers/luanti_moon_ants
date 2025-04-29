-- runtime/tick_scheduler.lua
-- Master loop scheduling and dispatching solver passes for active islands

dofile(minetest.get_modpath("moon") .. "/constants.lua")
dofile(minetest.get_modpath("moon") .. "/util.lua")
dofile(minetest.get_modpath("moon") .. "/islands/detector.lua")
dofile(minetest.get_modpath("moon") .. "/islands/queue.lua")
dofile(minetest.get_modpath("moon") .. "/solvers/electrical.lua")
dofile(minetest.get_modpath("moon") .. "/solvers/logic.lua")
dofile(minetest.get_modpath("moon") .. "/solvers/mechanical.lua")
dofile(minetest.get_modpath("moon") .. "/solvers/thermal.lua")
dofile(minetest.get_modpath("moon") .. "/solvers/chemistry.lua")
dofile(minetest.get_modpath("moon") .. "/solvers/rf.lua")
dofile(minetest.get_modpath("moon") .. "/solvers/material_flow.lua")
dofile(minetest.get_modpath("moon") .. "/solvers/mining.lua")

local MAX_VOXELS_PER_TICK = constants.MAX_VOXELS_PER_TICK or 10000
local IDLE_INTERVAL       = constants.IDLE_INTERVAL or 0.5
local TICK_LENGTH         = constants.TICK_LENGTH or 0.05

local tick_scheduler = {}

-- Internal state to track per-tick work
local processed_voxels_this_tick = 0
local max_islands_per_tick = constants.MAX_ISLANDS_PER_TICK or 64

-- Schedule an island for the next tick or after idle interval
local function reschedule_island(island, now, dirty)
    if dirty then
        queue.push(island, now + TICK_LENGTH)
    else
        queue.push(island, now + IDLE_INTERVAL)
    end
end

-- Master global-step callback
function tick_scheduler.global_step(dt)
    local now = minetest.get_gametime() + minetest.get_us_time() * 1e-6 / 1.0e6
    processed_voxels_this_tick = 0
    local processed_islands = 0

    -- Pop all islands due this tick
    local due_islands = queue.pop_due(now)
    if not due_islands or #due_islands == 0 then
        return
    end

    -- Deterministic sort: by island_id ascending
    table.sort(due_islands, function(a, b)
        return (a.id or 0) < (b.id or 0)
    end)

    for _, island in ipairs(due_islands) do
        -- Bound per-tick work
        if processed_islands >= max_islands_per_tick or
           processed_voxels_this_tick >= MAX_VOXELS_PER_TICK then
            -- Enqueue remaining islands for next tick
            queue.push(island, now + TICK_LENGTH)
            break
        end

        local dirty = false
        local rf_dirty = false

        -- Step 1: Electrical
        local electrical_dirty = electrical.step(island, dt)
        if electrical_dirty then
            dirty = true
        end

        -- Step 2: Logic (only if electrical changed)
        local logic_dirty = false
        if electrical_dirty then
            logic_dirty = logic.step(island, dt)
            if logic_dirty then
                dirty = true
            end
        end

        -- Step 3: Mechanical (always runs)
        local mechanical_dirty = mechanical.step(island, dt)
        if mechanical_dirty then
            dirty = true
        end

        -- Step 4: Thermal
        local thermal_dirty = thermal.step(island, dt)
        if thermal_dirty then
            dirty = true
        end

        -- Step 5: Chemistry
        local chemistry_dirty = chemistry.step(island, dt)
        if chemistry_dirty then
            dirty = true
        end

        -- Step 6: RF (only if any port transmitted)
        rf_dirty = rf.step(island, dt)
        if rf_dirty then
            dirty = true
        end

        -- Step 7: Material Flow
        local matflow_dirty = material_flow.step(island, dt)
        if matflow_dirty then
            dirty = true
        end

        -- Step 8: Mining
        local mining_dirty = mining.step(island, dt)
        if mining_dirty then
            dirty = true
        end

        -- Reschedule island
        reschedule_island(island, now, dirty)

        -- Track work
        processed_islands = processed_islands + 1
        if island.voxels and type(island.voxels) == "table" then
            processed_voxels_this_tick = processed_voxels_this_tick + util.table_count(island.voxels)
        end
        if processed_voxels_this_tick >= MAX_VOXELS_PER_TICK then
            break
        end
    end
end

return tick_scheduler

