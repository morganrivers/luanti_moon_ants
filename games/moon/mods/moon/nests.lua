---------------------------------------------------------------
-- moon/nests.lua  –  One-time starter burrow with energy
---------------------------------------------------------------
local BURROW_POS = {x = 0, y = -6, z = 0}
local BURROW_R   = 3          -- 7×7 cavity
local ENERGY_INI = 500

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

minetest.register_on_generated(function(minp, maxp, seed)
    if initialized then return end

    -- Check if this chunk contains the burrow location
    if  minp.x <= BURROW_POS.x and maxp.x >= BURROW_POS.x
    and minp.z <= BURROW_POS.z and maxp.z >= BURROW_POS.z
    and minp.y <= BURROW_POS.y and maxp.y >= BURROW_POS.y - 2 then

        local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
        local area  = VoxelArea:new{MinEdge=emin, MaxEdge=emax}
        local data  = vm:get_data()

        -- 1. Dig burrow chamber
        dig_cavity(vm, area, data, BURROW_POS, BURROW_R, 3)

        -- 2. Write modified map data
        vm:set_data(data)
        vm:write_to_map()

        -- 3. Place nest core
            local core_pos2 = {
            x = BURROW_POS.x,
            y = BURROW_POS.y - 2,  -- Place at bottom of cavity
            z = BURROW_POS.z
        }
        place_node(core_pos2, "moon:nest_core")

        local meta = minetest.get_meta(core_pos2)
        meta:set_int("eu", ENERGY_INI)

        -- 4. Place solar array directly above (at surface y = 1)
        local surface_pos = {x = BURROW_POS.x, y = 1, z = BURROW_POS.z}
        place_node(surface_pos, "moon:solar_array")
        minetest.get_node_timer(surface_pos):start(10)  -- begin charging

        -- 5. Spawn some ants inside the burrow
        for i = 1, 5 do
            local offset = {
                x = BURROW_POS.x + math.random(-2, 2),
                y = BURROW_POS.y - 1,
                z = BURROW_POS.z + math.random(-2, 2),
            }
            minetest.add_entity(offset, "moon:ant")
        end

        initialized = true
    end
end)
