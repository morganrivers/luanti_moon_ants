---------------------------------------------------------------
-- moon/nests.lua  –  One-time starter burrow with energy
---------------------------------------------------------------
local BURROW_POS = {x = 0, y = -6, z = 0}
local BURROW_R   = 3          -- 7×7 cavity
local ENERGY_INI = 500

-- Returns the first non‑air node when scanning downward.
local C_AIR    = minetest.get_content_id("air")
local C_IGNORE = minetest.get_content_id("ignore")

local function get_surface_y(area, data, x, z, ymin, ymax)
    -- start just above the chunk and scan downwards
    for y = ymax, ymin, -1 do
        local vi = area:index(x, y, z)
        local cid = data[vi]
        if cid ~= C_AIR and cid ~= C_IGNORE then
            return y -- this is the topmost solid node
        end
    end
    return nil           -- chunk was empty (shouldn’t happen after your map‑gen)
end


-- Helper to dig a cuboid chamber
local function dig_cavity(vm, area, data, center, radius, height)
    for dx = -radius, radius do
        for dz = -radius, radius do
            for dy = 0, height - 1 do
                local p = {
                    x = center.x + dx,
                    y = center.y - dy,
                    z = center.z + dz
                }
                if area:containsp(p) then
                    data[area:index(p.x, p.y, p.z)] = minetest.CONTENT_AIR
                end
            end
        end
    end
end

-- Helper to place a node only in air
local function place_node(p, name)
    local node = minetest.get_node_or_nil(p)
    if node and node.name == "air" then
        minetest.set_node(p, {name = name})
    end
end

-- Prevent multiple burrow generations
local initialized = false

-- minetest.register_on_generated(function(minp, maxp, seed)
--     if initialized then return end

--     -- Check if this chunk contains the burrow location
--     if  minp.x <= BURROW_POS.x and maxp.x >= BURROW_POS.x
--     and minp.z <= BURROW_POS.z and maxp.z >= BURROW_POS.z
--     and minp.y <= BURROW_POS.y and maxp.y >= BURROW_POS.y - 2 then

--         local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
--         local area  = VoxelArea:new{MinEdge=emin, MaxEdge=emax}
--         local data  = vm:get_data()

--         -- 1. Dig burrow chamber
--         dig_cavity(vm, area, data, BURROW_POS, BURROW_R, 3)

--         -- 2. Write modified map data
--         vm:set_data(data)
--         vm:write_to_map()

--         -- 3. Place nest core
--             local core_pos2 = {
--             x = BURROW_POS.x,
--             y = BURROW_POS.y - 2,  -- Place at bottom of cavity
--             z = BURROW_POS.z
--         }
--         place_node(core_pos2, "moon:nest_core")

--         local meta = minetest.get_meta(core_pos2)
--         meta:set_int("eu", ENERGY_INI)

--         -- 4. Place solar array directly above (at surface y = 1)
--         local surface_pos = {x = BURROW_POS.x, y = 1, z = BURROW_POS.z}
--         place_node(surface_pos, "moon:solar_array")
--         minetest.get_node_timer(surface_pos):start(10)  -- begin charging

--         -- 5. Spawn some ants inside the burrow
--         for i = 1, 5 do
--             local offset = {
--                 x = BURROW_POS.x + math.random(-2, 2),
--                 y = BURROW_POS.y - 1,
--                 z = BURROW_POS.z + math.random(-2, 2),
--             }
--             minetest.add_entity(offset, "moon:ant")
--         end

--         initialized = true
--     end
-- end)
minetest.register_on_generated(function(minp, maxp, seed)
    -- Make sure the burrow lives in this chunk
    if  not (minp.x <= BURROW_POS.x and maxp.x >= BURROW_POS.x
            and minp.z <= BURROW_POS.z and maxp.z >= BURROW_POS.z) then
        return
    end

    local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
    local area  = VoxelArea:new{MinEdge=emin, MaxEdge=emax}
    local data  = vm:get_data()

    -- NEW ► find the surface exactly at BURROW_POS.xz
    local surface_y = get_surface_y(
        area, data, BURROW_POS.x, BURROW_POS.z, emin.y, emax.y)

    if not surface_y then
        minetest.log("warning", "[moon] no solid ground found for nest!")
        return
    end

    -- Re‑anchor the cavity two nodes below the surface
    local burrow_center = {
        x = BURROW_POS.x,
        y = surface_y - 10,   -- ceiling of the chamber sits one node below ground
        z = BURROW_POS.z
    }

    dig_cavity(vm, area, data, burrow_center, BURROW_R, 3)

    -- Write map data immediately so later node placement sees air
    vm:set_data(data)
    vm:write_to_map()

    -- place core at floor, solar array at surface
    local core_pos = vector.new(burrow_center)
    core_pos.y = burrow_center.y - 2               -- bottom of the cavity
    minetest.set_node(core_pos, {name = "moon:nest_core"})
    minetest.get_meta(core_pos):set_int("eu", ENERGY_INI)

    local array_pos = vector.new(burrow_center)
    array_pos.y = surface_y + 1                    -- one node *above* ground
    minetest.set_node(array_pos, {name = "moon:solar_array"})
    minetest.get_node_timer(array_pos):start(10)

    -- spawn the ants inside
    for i = 1, 5 do
        minetest.add_entity(
            vector.add(core_pos, {x = math.random(-2, 2), y = 1, z = math.random(-2, 2)}),
            "moon:ant")
    end

    initialized = true
end)

-- -- Optional: put new players at the surface instead of mid‑air
-- minetest.register_on_newplayer(function(player)
--     local x, z = BURROW_POS.x, BURROW_POS.z
--     local y    = minetest.get_spawn_level and minetest.get_spawn_level(x, z)
--                or minetest.get_spawn_level   -- API fallback for old engines
--     -- `get_spawn_level` returns nil in singlenode, so fall back on our scan
--     if not y then
--         local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
--         local area  = VoxelArea:new{MinEdge=emin, MaxEdge=emax}
--         local data  = vm:get_data()
--         y = get_surface_y(area, data, x, z, emin.y, emax.y) or 0
--     end
--     player:set_pos({x = x + 0.5, y = y + 2, z = z + 0.5})
-- end)
