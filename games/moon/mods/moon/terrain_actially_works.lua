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
    
    -- Fill with flat terrain first
    for z = minp.z, maxp.z do
        for x = minp.x, maxp.x do
            for y = minp.y, maxp.y do
                local vi = area:index(x, y, z)
                
                if y <= surface_y then
                    -- Ground
                    data[vi] = CID_REG
                else
                    -- Air
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
                            
                            -- Add dark regolith at the very bottom
                            if dy == -crater_depth and y > minp.y then
                                local below_vi = area:index(px, y-1, pz)
                                if below_vi >= 1 and below_vi <= #data then
                                    data[below_vi] = CID_DARK_REG
                                end
                                
                                -- Half of deep craters get ice pools (3 blocks deep)
                                if crater_depth > 20 and math.random(1, 2) == 1 then
                                    -- Replace this air block with ice
                                    data[vi] = minetest.get_content_id("default:ice")
                                    
                                    -- Also check for ice in layers above (up to 3 blocks)
                                    for ice_y = 1, 2 do
                                        -- Only place ice if within crater and not too high
                                        if -crater_depth + ice_y <= 0 then
                                            local ice_vi = area:index(px, y + ice_y, pz)
                                            if ice_vi >= 1 and ice_vi <= #data then 
                                                data[ice_vi] = minetest.get_content_id("default:ice")
                                            end
                                        end
                                    end
                                end
                            end
                            
                            -- For existing ice craters, add ice for 3 layers
                            if depth_from_bottom > 0 and depth_from_bottom <= 2 and crater_depth > 20 then
                                -- Check if the bottom is ice (for consistency)
                                local bottom_y = surface_y - crater_depth
                                if bottom_y >= minp.y and bottom_y <= maxp.y then
                                    local bottom_check_vi = area:index(px, bottom_y, pz)
                                    if bottom_check_vi >= 1 and bottom_check_vi <= #data and
                                       data[bottom_check_vi] == minetest.get_content_id("default:ice") then
                                        -- Continue ice upward for this column
                                        data[vi] = minetest.get_content_id("default:ice")
                                    end
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