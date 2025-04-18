-- Lunar terrain with properly distributed craters and features

------------------------------------------------------------
-- Content‑IDs
------------------------------------------------------------
local CID_REG = minetest.get_content_id("moon:regolith")
local CID_LIGHT_REG = minetest.get_content_id("moon:light_regolith")
local CID_DARK_REG = minetest.get_content_id("moon:dark_regolith") 
local CID_BEDROCK = minetest.get_content_id("moon:bedrock")
local CID_METAL_ORE = minetest.get_content_id("moon:metal_ore")
local CID_ICE_ROCK = minetest.get_content_id("moon:ice_rock")
local CID_AIR = minetest.CONTENT_AIR

-- Crater configuration
local CRATER_DENSITY = 0.0025    -- Low density for distinct craters
local CRATER_MIN_DEPTH = 3       -- Shallow craters
local CRATER_MAX_DEPTH = 50      -- Deep craters
local SPAWN_PROTECTION_RADIUS = 25  -- Keep spawn area relatively flat

-- Resource configuration
local SURFACE_RESOURCE_CHANCE = 0.02  -- 2% chance of exposed resources on surface
local SHALLOW_RESOURCE_CHANCE = 0.05  -- 5% chance of shallow resources

------------------------------------------------------------
-- Generation callback
------------------------------------------------------------
minetest.register_on_generated(function(minp, maxp)
    -- Only generate near y=0 (flat plain)
    if minp.y > 60 or maxp.y < -60 then return end

    local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
    local area = VoxelArea:new{MinEdge = emin, MaxEdge = emax}
    local data = vm:get_data()
    
    -- Basic flat surface at y=0
    local surface_y = 0
    
    -- Fill with terrain and features
    for z = minp.z, maxp.z do
        for x = minp.x, maxp.x do
            -- Small terrain variations (subtle lunar plain undulations)
            local noise_val = math.sin(x * 0.05) * math.cos(z * 0.05) * 2
            local adjusted_surface_y = surface_y + math.floor(noise_val + 0.5)
            
            -- Below surface bedrock layer
            local bedrock_start = -30 - math.abs(math.sin(x * 0.02) * 10)
            
            for y = minp.y, maxp.y do
                local vi = area:index(x, y, z)
                
                if y <= adjusted_surface_y then
                    if y < bedrock_start then
                        -- Deep lunar bedrock
                        data[vi] = CID_BEDROCK
                        
                        -- Rare chance of deep resources
                        if math.random() < 0.005 then
                            if math.random() < 0.7 then
                                data[vi] = CID_METAL_ORE  -- 70% metal at depth
                            else
                                data[vi] = CID_ICE_ROCK   -- 30% ice at depth
                            end
                        end
                    else
                        -- Standard regolith, with occasional shallow resources
                        data[vi] = CID_REG
                        
                        -- Surface-exposed or very shallow resources
                        if (y == adjusted_surface_y and math.random() < SURFACE_RESOURCE_CHANCE) or
                           (y > adjusted_surface_y - 5 and math.random() < SHALLOW_RESOURCE_CHANCE) then
                            local resource_roll = math.random()
                            if resource_roll < 0.6 then
                                data[vi] = CID_METAL_ORE  -- 60% metal near surface
                            elseif resource_roll < 0.9 then 
                                data[vi] = CID_LIGHT_REG  -- 30% light regolith variation
                            else
                                data[vi] = CID_DARK_REG   -- 10% dark regolith variation
                            end
                        end
                    end
                else
                    -- Air above surface
                    data[vi] = CID_AIR
                end
            end
        end
    end
    
    -- Add craters with skewed distribution (many shallow, few deep)
    local chunk_size_x = maxp.x - minp.x + 1
    local chunk_size_z = maxp.z - minp.z + 1
    local chunk_area = chunk_size_x * chunk_size_z
    local crater_count = math.floor(chunk_area * CRATER_DENSITY)
    
    -- Create random number generator with seed based on chunk position
    local seed = minp.x * 65536 + minp.z
    math.randomseed(seed)
    
    for i = 1, crater_count do
        -- Random position within chunk
        local x = minp.x + math.random(0, chunk_size_x - 1)
        local z = minp.z + math.random(0, chunk_size_z - 1)
        
        -- Random crater depth - skewed distribution (most ~5-15, very few ~40-50)
        -- Use exponential-like distribution with square root
        local depth_rand = math.random() * math.random()  -- Square gives skew toward 0
        local crater_depth = math.floor(CRATER_MIN_DEPTH + depth_rand * (CRATER_MAX_DEPTH - CRATER_MIN_DEPTH))
        local crater_radius = math.floor(crater_depth * 0.8)  -- Slightly narrower craters
        
        -- Check spawn protection - include crater radius
        local spawn_dist_sq = x*x + z*z
        local is_protected = spawn_dist_sq < (SPAWN_PROTECTION_RADIUS + crater_radius)^2
            
        -- Only create crater if not in protected area
        if not is_protected then
            -- Create crater
            for dy = -crater_depth, 0 do
                -- Calculate radius at this depth (parabolic shape)
                local depth_ratio = dy / -crater_depth
                local slice_radius = math.floor(crater_radius * math.sqrt(1 - depth_ratio * depth_ratio))
                local y = surface_y + dy
                
                -- Skip if outside chunk height range
                if y < minp.y or y > maxp.y then
                    goto continue_dy
                end
                
                -- Create circular slice
                for dx = -slice_radius, slice_radius do
                    for dz = -slice_radius, slice_radius do
                        -- Check if within circular slice
                        if dx*dx + dz*dz <= slice_radius*slice_radius then
                            local px = x + dx
                            local pz = z + dz
                            
                            -- Skip if outside chunk horizontal bounds
                            if px < minp.x or px > maxp.x or pz < minp.z or pz > maxp.z then
                                goto continue_dz
                            end
                            
                            -- Dig out crater
                            local vi = area:index(px, y, pz)
                            data[vi] = CID_AIR
                            
                            -- Add materials at the bottom
                            -- Check if we're at the bottom or within 3 blocks of the bottom
                            local depth_from_bottom = crater_depth + dy
                            
                            -- Resource-filled crater bottoms
                            if depth_from_bottom <= 3 then
                                -- We're in the bottom 3 layers of the crater - fill with resources
                                
                                -- Crater resource type is determined by depth
                                if crater_depth > 25 then
                                    -- Deep craters (>25 blocks) have lots of ice
                                    local resource_roll = math.random()
                                    if resource_roll < 0.7 then  -- 70% chance
                                        -- Fill with ice - valuable resource
                                        data[vi] = CID_ICE_ROCK
                                    elseif resource_roll < 0.9 then  -- 20% chance 
                                        -- Some metal in ice craters
                                        data[vi] = CID_METAL_ORE
                                    else  -- 10% chance
                                        -- Some dark regolith mixed in
                                        data[vi] = CID_DARK_REG
                                    end
                                elseif crater_depth > 12 then
                                    -- Medium craters (12-25 blocks) have mixed resources
                                    local resource_roll = math.random()
                                    if resource_roll < 0.4 then  -- 40% chance
                                        -- Metal deposits
                                        data[vi] = CID_METAL_ORE
                                    elseif resource_roll < 0.7 then  -- 30% chance 
                                        -- Some ice in medium craters
                                        data[vi] = CID_ICE_ROCK
                                    else  -- 30% chance
                                        -- Some dark regolith
                                        data[vi] = CID_DARK_REG
                                    end
                                else
                                    -- Shallow craters (<12 blocks) mostly have metal
                                    local resource_roll = math.random()
                                    if resource_roll < 0.6 then  -- 60% chance
                                        -- Mostly metal deposits
                                        data[vi] = CID_METAL_ORE
                                    elseif resource_roll < 0.7 then  -- 10% chance 
                                        -- Rare ice in shallow craters
                                        data[vi] = CID_ICE_ROCK
                                    else  -- 30% chance
                                        -- Some dark regolith
                                        data[vi] = CID_DARK_REG
                                    end
                                end
                            end
                            
                            -- Add dark regolith just below the crater
                            if dy == -crater_depth and y > minp.y then
                                local below_vi = area:index(px, y-1, pz)
                                if below_vi >= 1 and below_vi <= #data then
                                    data[below_vi] = CID_DARK_REG
                                end
                            end
                        end
                        ::continue_dz::
                    end
                end
                ::continue_dy::
            end
        end
    end

    vm:set_data(data)
    vm:write_to_map()
end)