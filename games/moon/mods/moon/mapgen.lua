minetest.register_alias("mapgen_water_source", "air")
minetest.register_alias("mapgen_river_water_source", "air")
minetest.register_alias("mapgen_lava_source", "air")

-- Set the mapgen to singlenode to prevent default terrain generation
minetest.set_mapgen_setting("mg_name", "singlenode", true)

-- Register moon biome
minetest.register_biome({
    name = "moon_regolith",
    node_top = "moon:regolith",
    depth_top = 1,
    node_filler = "moon:regolith",
    depth_filler = 3,
    y_max = 1000,
    y_min = -31000,
    heat_point = 0,
    humidity_point = 0,
})

-- Add occasional ice patches in permanently shadowed craters (rare)
minetest.register_on_generated(function(minp, maxp, blockseed)
    -- Only consider chunks near the surface
    if minp.y > 10 or maxp.y < -20 then
        return
    end
    
    local pr = PseudoRandom(blockseed + 1521)
    
    -- Very rare chance for an ice patch (1 in 500 chunks)
    if pr:next(1, 500) <= 1 then
        -- Find a crater or low point for the ice
        local ice_pos = {
            x = pr:next(minp.x, maxp.x),
            y = pr:next(-10, -3),  -- Usually in low areas
            z = pr:next(minp.z, maxp.z)
        }
        
        -- Get node IDs for ice patch
        local vm = minetest.get_voxel_manip()
        local emin, emax = vm:read_from_map(
            {x = ice_pos.x - 5, y = ice_pos.y - 1, z = ice_pos.z - 5},
            {x = ice_pos.x + 5, y = ice_pos.y + 1, z = ice_pos.z + 5}
        )
        local area = VoxelArea:new{MinEdge=emin, MaxEdge=emax}
        local data = vm:get_data()
        
        -- Create ice node (we'll use default:ice since it already exists)
        local c_ice = minetest.get_content_id("default:ice")
        
        -- Generate a small ice patch
        local radius = pr:next(2, 5)
        for z = ice_pos.z - radius, ice_pos.z + radius do
            for x = ice_pos.x - radius, ice_pos.x + radius do
                local dx = x - ice_pos.x
                local dz = z - ice_pos.z
                local dist = math.sqrt(dx*dx + dz*dz)
                
                if dist <= radius then
                    -- Ice patch at this position
                    local vi = area:index(x, ice_pos.y, z)
                    data[vi] = c_ice
                end
            end
        end
        
        -- Write data back to the map
        vm:set_data(data)
        vm:write_to_map()
        vm:update_map()
    end
end)

-- Add rare boulders scattered on the surface
minetest.register_on_generated(function(minp, maxp, blockseed)
    -- Only consider chunks near the surface
    if minp.y > 10 or maxp.y < -1 then
        return
    end
    
    local pr = PseudoRandom(blockseed + 9731)
    
    -- Chance for boulders in this chunk (1 in 4 chunks)
    if pr:next(1, 4) <= 1 then
        local vm = minetest.get_voxel_manip()
        local emin, emax = vm:read_from_map(minp, maxp)
        local area = VoxelArea:new{MinEdge=emin, MaxEdge=emax}
        local data = vm:get_data()
        
        -- Get node ID for bedrock (our boulder material)
        local c_bedrock = minetest.get_content_id("moon:bedrock")
        
        -- Number of boulders to try placing
        local boulder_count = pr:next(1, 3)
        
        for i = 1, boulder_count do
            -- Random position in chunk
            local boulder_pos = {
                x = pr:next(minp.x, maxp.x),
                y = 0,  -- Will be adjusted to surface height
                z = pr:next(minp.z, maxp.z)
            }
            
            -- Find surface height at this position
            for y = maxp.y, minp.y, -1 do
                local vi = area:index(boulder_pos.x, y, boulder_pos.z)
                -- Check for air - when we find the first non-air block, that's the surface
                if data[vi] ~= minetest.get_content_id("air") then
                    boulder_pos.y = y + 1  -- Place boulder on top of surface
                    break
                end
            end
            
            -- Create boulder if we found a valid position
            if boulder_pos.y > minp.y then
                -- Randomly sized boulder
                local size = pr:next(1, 3)
                
                if size == 1 then
                    -- Small boulder (single block)
                    local vi = area:index(boulder_pos.x, boulder_pos.y, boulder_pos.z)
                    data[vi] = c_bedrock
                elseif size == 2 then
                    -- Medium boulder (2x2x1)
                    for dx = 0, 1 do
                        for dz = 0, 1 do
                            local vi = area:index(boulder_pos.x + dx, boulder_pos.y, boulder_pos.z + dz)
                            data[vi] = c_bedrock
                        end
                    end
                else
                    -- Large boulder (2x2x2 with randomized top)
                    for dx = 0, 1 do
                        for dz = 0, 1 do
                            -- Bottom layer
                            local vi = area:index(boulder_pos.x + dx, boulder_pos.y, boulder_pos.z + dz)
                            data[vi] = c_bedrock
                            
                            -- Top layer (random)
                            if pr:next(1, 4) > 1 then  -- 75% chance
                                local vi_top = area:index(boulder_pos.x + dx, boulder_pos.y + 1, boulder_pos.z + dz)
                                data[vi_top] = c_bedrock
                            end
                        end
                    end
                end
            end
        end
        
        -- Write data back to the map
        vm:set_data(data)
        vm:write_to_map()
        vm:update_map()
    end
end)
	
