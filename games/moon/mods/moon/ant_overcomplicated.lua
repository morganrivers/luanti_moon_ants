-- Lunar Resource Collection Rover Entity

minetest.log("action", "[ROVER MOD] Registering rover entity")

-- Helper function to find nearest node of a specific group within radius
local function find_nearest_node(pos, group, radius)
    radius = radius or 8  -- Default search radius
    local nearest_pos = nil
    local nearest_dist = radius + 1  -- Initialize beyond max range
    
    -- Search in a cube area around the position
    for x = -radius, radius do
        for y = -radius, radius do
            for z = -radius, radius do
                local check_pos = vector.add(pos, {x=x, y=y, z=z})
                local node = minetest.get_node_or_nil(check_pos)
                
                if node and minetest.get_item_group(node.name, group) > 0 then
                    local dist = vector.distance(pos, check_pos)
                    if dist < nearest_dist then
                        nearest_dist = dist
                        nearest_pos = check_pos
                    end
                end
            end
        end
    end
    
    return nearest_pos, nearest_dist
end

-- Helper function to find nearest nest core
local function find_nearest_nest(pos, radius)
    return find_nearest_node(pos, "nest_core", radius)
end

-- Register the rover entity
minetest.register_entity("moon:ant", {
    initial_properties = {
        physical = true,
        collide_with_objects = true,
        collisionbox = {-0.3, -0.01, -0.3, 0.3, 0.25, 0.3},
        visual = "sprite",  -- Using sprite is more reliable than mesh
        textures = {"ant.png"}, 
        visual_size = {x = 1.2, y = 1.2},  -- Slightly larger for visibility
        nametag = "Rover Unit",
        nametag_color = "#00AAFF",
        is_visible = true,
        makes_footstep_sound = true,
    },
    
    -- Entity variables
    timer = 0,
    move_timer = 0,
    
    -- Rover state system: "SEARCH", "EXPLORE", "MINE", "RETURN"
    state = "SEARCH",
    target_pos = nil,
    inventory = {regolith = 0, metal = 0, ice = 0},
    
    -- Exploration variables
    explore_dir = nil,  -- Direction when exploring (vector)
    explore_distance = 0, -- Distance traveled in current direction
    path_history = {}, -- Track path for return journey
    last_dig_time = 0, -- Time of last tunnel digging
    
    -- Default genetic traits (can be overridden by blueprint)
    traits = nil,
    base_speed = 0.5,
    search_radius = 8,  -- Regular resource detection
    ice_search_radius = 20, -- Special ice detection radius
    
    on_activate = function(self, staticdata)
        minetest.log("action", "[ROVER MOD] Rover unit activated at " .. 
            minetest.pos_to_string(self.object:get_pos()))
        
        -- COMPLETELY DISABLE GRAVITY - set zero acceleration
        self.object:set_acceleration({x=0, y=0, z=0})
        
        -- Set physical properties to prevent falling
        self.object:set_properties({
            physical = true,
            collide_with_objects = true,
            static_save = true,
            makes_footstep_sound = true,
            automatic_face_movement_dir = false  -- Don't automatically turn
        })
        
        -- Initialize state machine
        self.state = "SEARCH"
        self.target_pos = nil
        self.inventory = {regolith = 0, metal = 0, ice = 0}
        
        -- Initialize exploration variables
        self.explore_dir = nil
        self.explore_distance = 0
        self.path_history = {}
        self.last_dig_time = 0
        
        -- Initialize genetic traits if not already set
        if not self.traits and moon_genetics then
            self.traits = moon_genetics.get_default_traits()
        end
        
        -- Apply traits to rover behavior
        if self.traits then
            self.base_speed = self.traits.speed or self.base_speed
            self.search_radius = self.traits.search_radius or self.search_radius
            -- Ice search radius can be enhanced by traits
            if self.traits.search_radius then
                self.ice_search_radius = math.min(30, self.traits.search_radius * 2.5)
            end
        end
        
        -- Initial movement
        local yaw = math.random() * math.pi * 2
        self.object:set_yaw(yaw)
        self.object:set_velocity({
            x = math.cos(yaw) * self.base_speed,
            y = 0,
            z = math.sin(yaw) * self.base_speed,
        })
        
        -- Restore from staticdata if available
        if staticdata and staticdata ~= "" then
            local data = minetest.deserialize(staticdata)
            if data then
                if data.traits then self.traits = data.traits end
                if data.inventory then self.inventory = data.inventory end
                if data.state then self.state = data.state end
                if data.path_history then self.path_history = data.path_history end
                if data.explore_dir then self.explore_dir = data.explore_dir end
                if data.explore_distance then self.explore_distance = data.explore_distance end
            end
        end
        
        -- Set working nametag with state
        self:update_nametag()
    end,
    
    -- Save traits, state, and exploration data when the entity is unloaded
    get_staticdata = function(self)
        local data = {
            traits = self.traits,
            inventory = self.inventory,
            state = self.state,
            path_history = self.path_history,
            explore_dir = self.explore_dir,
            explore_distance = self.explore_distance
        }
        return minetest.serialize(data)
    end,
    
    -- Update the nametag to show current state and inventory
    update_nametag = function(self)
        local inv_text = string.format("Si:%d Fe:%d H₂O:%d", 
            self.inventory.regolith or 0,
            self.inventory.metal or 0,
            self.inventory.ice or 0)
            
        self.object:set_properties({
            nametag = string.format("Rover [%s] %s", self.state, inv_text),
            nametag_color = self:get_state_color()
        })
    end,
    
    -- Get color based on state
    get_state_color = function(self)
        if self.state == "SEARCH" then return "#00AAFF"      -- Blue
        elseif self.state == "EXPLORE" then return "#FFFF00" -- Yellow
        elseif self.state == "MINE" then return "#00FF00"    -- Green
        elseif self.state == "RETURN" then return "#FF9900"  -- Orange
        else return "#FF0000" end                            -- Red (default)
    end,
    
    -- Helper function to deposit resources at a hub
    deposit_resources = function(self, hub_pos)
        local meta = minetest.get_meta(hub_pos)
        
        -- Update hub inventory counters
        local nest_inv = {
            regolith = meta:get_int("regolith") + self.inventory.regolith,
            metal = meta:get_int("metal") + self.inventory.metal,
            ice = meta:get_int("ice") + self.inventory.ice
        }
        
        -- Special handling for ice delivery
        if self.inventory.ice > 0 then
            -- Add special visual effects for ice delivery
            minetest.add_particlespawner({
                amount = 20,
                time = 1.0,
                minpos = {x=hub_pos.x-0.5, y=hub_pos.y, z=hub_pos.z-0.5},
                maxpos = {x=hub_pos.x+0.5, y=hub_pos.y+1, z=hub_pos.z+0.5},
                minvel = {x=-0.5, y=0.5, z=-0.5},
                maxvel = {x=0.5, y=1.5, z=0.5},
                minacc = {x=0, y=-0.2, z=0},
                maxacc = {x=0, y=0, z=0},
                minexptime = 1,
                maxexptime = 2,
                minsize = 2,
                maxsize = 4,
                collisiondetection = false,
                texture = "bubble.png^[colorize:#00FFFF:127",
            })
            
            -- Log ice delivery with prominence
            minetest.log("action", "[ROVER MOD] !!! ICE DELIVERED !!! Rover has delivered " .. 
                self.inventory.ice .. " units of water ice to fabrication hub.")
            
            -- If genetic system exists, record the successful ice delivery
            if moon_genetics and moon_genetics.record_efficiency then
                moon_genetics.record_efficiency(self, "ice_delivery", self.inventory.ice * 5)  -- Ice deliveries worth 5x normal
            end
            
            -- Give extra energy to hub when ice is delivered (represents increased fabrication capabilities)
            if moon_energy then
                moon_energy.add(hub_pos, self.inventory.ice * 10)  -- 10 energy per ice unit
                minetest.log("action", "[ROVER MOD] Ice electrolysis added " .. 
                    (self.inventory.ice * 10) .. " energy to fabrication hub")
            end
        else
            -- Log regular resource delivery
            minetest.log("action", "[ROVER MOD] Resources delivered: " .. 
                self.inventory.regolith .. " regolith, " .. 
                self.inventory.metal .. " metal")
        end
        
        -- Store updated values
        meta:set_int("regolith", nest_inv.regolith)
        meta:set_int("metal", nest_inv.metal)
        meta:set_int("ice", nest_inv.ice)
        
        -- Update the infotext
        meta:set_string("infotext", string.format(
            "Fabrication Hub\nRegolith: %d\nMetal: %d\nIce: %d\nEnergy: %d EU",
            nest_inv.regolith, nest_inv.metal, nest_inv.ice,
            moon_energy.get(hub_pos)
        ))
        
        -- Empty rover inventory
        self.inventory = {regolith = 0, metal = 0, ice = 0}
        
        -- Reset exploration variables
        self.explore_dir = nil
        self.explore_distance = 0
        self.path_history = {}
        
        -- Go back to searching
        self.state = "SEARCH"
    end,
    
    -- Check inventory weight to affect movement speed
    get_speed_factor = function(self)
        local total_weight = self.inventory.regolith + self.inventory.metal + self.inventory.ice
        local capacity = (self.traits and self.traits.carrying_capacity) or 1
        
        -- Reduce speed as weight increases (min speed 40%)
        -- Better carrying capacity reduces the speed penalty
        local weight_factor = math.max(0.4, 1.0 - (total_weight * 0.05 / capacity))
        
        return weight_factor
    end,
    
    -- Initialize a new exploration direction (STRICTLY HORIZONTAL ONLY!)
    start_exploration = function(self)
        -- Define ONLY horizontal cardinal directions (N, S, E, W)
        local directions = {
            {x=1, y=0, z=0},   -- East
            {x=-1, y=0, z=0},  -- West
            {x=0, y=0, z=1},   -- North
            {x=0, y=0, z=-1}   -- South
        }
        
        -- Force horizontal direction with y=0
        self.explore_dir = directions[math.random(1, 4)]
        
        -- Explicitly ensure Y component is zero
        self.explore_dir.y = 0
        
        self.explore_distance = 0
        self.path_history = {}
        
        local pos = self.object:get_pos()
        if pos then
            -- Record starting position
            table.insert(self.path_history, {x=math.floor(pos.x + 0.5), y=math.floor(pos.y + 0.5), z=math.floor(pos.z + 0.5)})
        end
        
        -- Set facing direction based on exploration vector
        -- Force the facing to be exactly horizontal
        local yaw = minetest.dir_to_yaw(self.explore_dir)
        self.object:set_yaw(yaw)
        
        -- Log exploration start with a clear note about horizontal movement
        minetest.log("action", "[ROVER MOD] Starting HORIZONTAL ONLY exploration in direction " .. 
            minetest.pos_to_string(self.explore_dir))
    end,
    
    -- Make a 90 degree turn and continue exploring (strictly horizontal)
    change_direction = function(self)
        if not self.explore_dir then
            self:start_exploration()
            return
        end
        
        -- Reset distance counter
        self.explore_distance = 0
        
        -- 90 degree rotation (choose left or right randomly)
        local turn_left = (math.random() > 0.5)
        local new_dir = {}
        
        -- Ensure we're only dealing with horizontal components
        local horizontal_dir = {
            x = self.explore_dir.x,
            y = 0,
            z = self.explore_dir.z
        }
        
        if turn_left then
            -- Rotate 90° left (counterclockwise)
            new_dir = {
                x = -horizontal_dir.z,
                y = 0,
                z = horizontal_dir.x
            }
        else
            -- Rotate 90° right (clockwise)
            new_dir = {
                x = horizontal_dir.z,
                y = 0,
                z = -horizontal_dir.x
            }
        end
        
        self.explore_dir = new_dir
        
        -- Set facing direction based on new exploration vector
        local yaw = minetest.dir_to_yaw(self.explore_dir)
        self.object:set_yaw(yaw)
        
        -- Log direction change
        minetest.log("action", "[ROVER MOD] Changed exploration direction to " .. 
            minetest.pos_to_string(self.explore_dir) .. " (turned " .. (turn_left and "left" or "right") .. ")")
    end,
    
    -- Dig a block in the direction we're exploring (STRICTLY HORIZONTAL ONLY)
    dig_exploration_tunnel = function(self)
        if not self.explore_dir then return false end
        
        -- SAFETY - Set explore_dir to a completely new horizontal direction if needed
        if self.explore_dir.y ~= 0 then
            -- Force a completely new cardinal direction
            local cardinal_directions = {
                {x=1, y=0, z=0},   -- East
                {x=-1, y=0, z=0},  -- West
                {x=0, y=0, z=1},   -- North
                {x=0, y=0, z=-1}   -- South
            }
            self.explore_dir = cardinal_directions[math.random(1, 4)]
            minetest.log("action", "[ROVER MOD] EMERGENCY DIRECTION RESET: " .. 
                minetest.pos_to_string(self.explore_dir))
        end
        
        -- Get position in front of rover
        local pos = self.object:get_pos()
        if not pos then return false end
        
        -- Round to nearest block center
        pos = {x=math.floor(pos.x + 0.5), y=math.floor(pos.y + 0.5), z=math.floor(pos.z + 0.5)}
        
        -- FORCE PURE HORIZONTAL MOVEMENT
        local pure_horizontal_dir = {
            x = self.explore_dir.x,
            y = 0,  -- FORCE ZERO
            z = self.explore_dir.z
        }
                
        -- Calculate target position EXACTLY on same Y level
        local front_pos = {
            x = pos.x + pure_horizontal_dir.x,
            y = pos.y,  -- EXACT SAME HEIGHT
            z = pos.z + pure_horizontal_dir.z
        }
        
        -- Make triple-sure we're not digging down
        if front_pos.y < pos.y then
            minetest.log("action", "[ROVER MOD] CRITICAL ERROR - Attempted to dig DOWN! Correcting!")
            front_pos.y = pos.y
        end
        
        -- Verify one final time we're EXACTLY at the same level
        if front_pos.y ~= pos.y then
            minetest.log("action", "[ROVER MOD] EMERGENCY Y ADJUSTMENT - Fixing to exact same height!")
            front_pos.y = pos.y
        end
        
        -- Check if the block is diggable - ONE FINAL HORIZONTAL CHECK
        local node = minetest.get_node(front_pos)
        if node and front_pos.y == pos.y and (node.name == "moon:regolith" or 
                    node.name == "default:stone" or 
                    node.name == "moon:bedrock") then
            
            -- Record current position in path history
            table.insert(self.path_history, {x=pos.x, y=pos.y, z=pos.z})
            
            -- Dig the block
            minetest.dig_node(front_pos)
            
            -- Add particle effects for drilling
            minetest.add_particlespawner({
                amount = 10,
                time = 0.5,
                minpos = {x=front_pos.x-0.2, y=front_pos.y, z=front_pos.z-0.2},
                maxpos = {x=front_pos.x+0.2, y=front_pos.y+0.3, z=front_pos.z+0.2},
                minvel = {x=-0.5, y=0.5, z=-0.5},
                maxvel = {x=0.5, y=1, z=0.5},
                minacc = {x=0, y=0, z=0},
                maxacc = {x=0, y=0, z=0},
                minexptime = 0.5,
                maxexptime = 1,
                minsize = 1,
                maxsize = 2,
                collisiondetection = false,
                texture = "moon_regolith.png",
            })
            
            -- Move into the dug area, keeping Y position the same
            self.object:set_pos({x=front_pos.x, y=pos.y, z=front_pos.z})
            
            -- Extra sanity check on our position
            local new_pos = self.object:get_pos()
            if new_pos.y ~= pos.y then
                self.object:set_pos({x=new_pos.x, y=pos.y, z=new_pos.z})
                minetest.log("action", "[ROVER MOD] CRITICAL: Fixed vertical position drift")
            end
            
            -- Increment exploration distance
            self.explore_distance = self.explore_distance + 1
            
            -- EXACTLY every 10 blocks, turn 90 degrees - no exceptions
            if self.explore_distance % 10 == 0 then
                self:change_direction()
                minetest.log("action", "[ROVER MOD] EXACTLY 10 BLOCKS REACHED - TURNING 90 DEGREES to " ..
                    minetest.pos_to_string(self.explore_dir))
                
                -- Reset exploration distance counter
                self.explore_distance = 0
            end
            
            return true
        end
        
        return false
    end,
    
    -- Check for nearby ice deposits with a larger radius
    find_ice = function(self)
        local pos = self.object:get_pos()
        if not pos then return nil end
        
        -- Use extended ice search radius
        local ice_pos = find_nearest_node(pos, "ice_rock", self.ice_search_radius)
        return ice_pos
    end,
    
    -- Backtrack using the stored path history (STRICTLY FOLLOW PATH BACKWARDS)
    backtrack = function(self)
        if #self.path_history == 0 then
            -- No path to follow, switch to search
            self.state = "SEARCH"
            minetest.log("action", "[ROVER MOD] Backtracking complete - path history exhausted")
            return false
        end
        
        -- Get the last position from our path
        local last_pos = self.path_history[#self.path_history]
        
        -- Calculate direction to last position
        local pos = self.object:get_pos()
        
        -- Remove the position we're going to from the path history
        table.remove(self.path_history)
        
        -- Calculate direction - FORCE HORIZONTAL MOVEMENT
        local dir = vector.direction(pos, last_pos)
        
        -- Create a strictly horizontal direction
        local horizontal_dir = {
            x = dir.x,
            y = 0,  -- No vertical component
            z = dir.z
        }
        
        -- Set yaw to face that horizontal direction only
        local yaw = minetest.dir_to_yaw(horizontal_dir)
        self.object:set_yaw(yaw)
        
        -- Check if path is blocked (something may have changed)
        local node_at_target = minetest.get_node(last_pos)
        if node_at_target.name ~= "air" then
            -- Path is blocked, try to dig through
            minetest.log("action", "[ROVER MOD] Backtrack path blocked, attempting to dig through")
            minetest.dig_node(last_pos)
            
            -- Add some particles to show the digging
            minetest.add_particlespawner({
                amount = 10,
                time = 0.5,
                minpos = {x=last_pos.x-0.2, y=last_pos.y, z=last_pos.z-0.2},
                maxpos = {x=last_pos.x+0.2, y=last_pos.y+0.3, z=last_pos.z+0.2},
                minvel = {x=-0.5, y=0.5, z=-0.5},
                maxvel = {x=0.5, y=1, z=0.5},
                minacc = {x=0, y=0, z=0},
                maxacc = {x=0, y=0, z=0},
                minexptime = 0.5,
                maxexptime = 1,
                minsize = 1,
                maxsize = 2,
                collisiondetection = false,
                texture = "moon_regolith.png",
            })
        end
        
        -- Move to that position (whether we had to dig or not)
        self.object:set_pos(last_pos)
        
        -- Leave breadcrumb particles for debugging path history
        if self.inventory.ice > 0 then
            -- Leave more visible trail when carrying ice
            minetest.add_particlespawner({
                amount = 5,
                time = 8.0,  -- Trail lasts longer to show the path
                minpos = {x=last_pos.x-0.1, y=last_pos.y, z=last_pos.z-0.1},
                maxpos = {x=last_pos.x+0.1, y=last_pos.y+0.3, z=last_pos.z+0.1},
                minvel = {x=0, y=0, z=0},
                maxvel = {x=0, y=0.01, z=0},
                minacc = {x=0, y=0, z=0},
                maxacc = {x=0, y=0, z=0},
                minexptime = 5.0,
                maxexptime = 8.0,
                minsize = 1,
                maxsize = 2,
                collisiondetection = false,
                texture = "bubble.png^[colorize:#00FFFF:127",
            })
            
            -- Log regular updates about backtracking with ice
            if #self.path_history % 5 == 0 then
                minetest.log("action", "[ROVER MOD] Returning with ice - " .. 
                    #self.path_history .. " steps remaining in path")
            end
        end
        
        return true
    end,
    
    -- Finite state machine for rover behavior
    step_state = function(self, dtime)
        local pos = self.object:get_pos()
        
        if self.state == "SEARCH" then
            -- First make sure we're not stuck - if we've been searching for a while, go explore
            if math.random() < 0.05 then  -- 5% chance to force exploration
                -- Switch to exploration mode
                self.state = "EXPLORE"
                self:start_exploration()
                minetest.log("action", "[ROVER MOD] Bored of searching - switching to exploration mode")
                return
            end
            
            -- First, check for ice with extended radius (priority resource)
            local ice_pos = self:find_ice()
            
            if ice_pos then
                -- Found ice! Switch to MINE state to collect it
                self.state = "MINE"
                self.target_pos = ice_pos
                
                -- Clear path history for a fresh return journey
                self.path_history = {}
                local current_pos = {
                    x = math.floor(pos.x + 0.5), 
                    y = math.floor(pos.y + 0.5), 
                    z = math.floor(pos.z + 0.5)
                }
                table.insert(self.path_history, current_pos)
                
                minetest.log("action", "[ROVER MOD] Ice detected at " .. 
                    minetest.pos_to_string(ice_pos) .. ", moving to mine")
            else
                -- No ice found within detection range, look for other resources
                local resource_found = false
                local resources = {"regolith", "metal_ore"}
                
                -- Use the rover's regular search radius for common resources
                local search_radius = self.search_radius or 8
                
                for _, resource in ipairs(resources) do
                    local resource_pos = find_nearest_node(pos, resource, search_radius)
                    
                    if resource_pos then
                        -- Found a resource, switch to MINE state and move toward it
                        self.state = "MINE"
                        self.target_pos = resource_pos
                        resource_found = true
                        minetest.log("action", "[ROVER MOD] Found " .. resource .. " resource at " .. 
                            minetest.pos_to_string(resource_pos))
                        break
                    end
                end
                
                -- Move randomly during SEARCH to avoid getting stuck
                if not resource_found and math.random() < 0.1 then
                    -- Apply a small random movement
                    local random_angle = math.random() * 2 * math.pi
                    self.object:set_yaw(random_angle)
                    self.object:set_velocity({
                        x = math.cos(random_angle) * 0.5,
                        y = 0,
                        z = math.sin(random_angle) * 0.5
                    })
                    minetest.log("action", "[ROVER MOD] Random search movement")
                end
                
                -- If no resources found in regular search, start/continue exploring
                if not resource_found then
                    -- Switch to exploration mode
                    self.state = "EXPLORE"
                    
                    -- ALWAYS initialize new exploration every time we switch to EXPLORE
                    -- This ensures continuous horizontal exploration
                    self:start_exploration()
                    
                    minetest.log("action", "[ROVER MOD] Switching to EXPLORE mode and starting horizontal exploration")
                end
            end
            
        elseif self.state == "EXPLORE" then
            -- ALWAYS make sure we have a valid exploration direction
            if not self.explore_dir then
                self:start_exploration()
                minetest.log("action", "[ROVER MOD] Forced new exploration direction")
            end
            
            -- Check for ice more frequently during exploration (30% chance per step)
            if math.random() < 0.3 then
                local ice_pos = self:find_ice()
                if ice_pos then
                    -- Found ice! Switch to MINE state
                    self.state = "MINE"
                    self.target_pos = ice_pos
                    
                    -- Don't clear path history - we need it to return via the same tunnel
                    
                    -- Log discovery with extra prominence
                    minetest.log("action", "[ROVER MOD] !!! ICE DETECTED !!! during exploration at " .. 
                        minetest.pos_to_string(ice_pos) .. ", moving to mine")
                    
                    -- Add particles to show detection
                    minetest.add_particlespawner({
                        amount = 30,
                        time = 1.0,
                        minpos = {x=self.object:get_pos().x-1, y=self.object:get_pos().y, z=self.object:get_pos().z-1},
                        maxpos = {x=self.object:get_pos().x+1, y=self.object:get_pos().y+1, z=self.object:get_pos().z+1},
                        minvel = {x=-0.5, y=0.5, z=-0.5},
                        maxvel = {x=0.5, y=1.5, z=0.5},
                        minacc = {x=0, y=0, z=0},
                        maxacc = {x=0, y=0, z=0},
                        minexptime = 1,
                        maxexptime = 2,
                        minsize = 2,
                        maxsize = 4,
                        collisiondetection = false,
                        texture = "bubble.png^[colorize:#00FFFF:127",
                    })
                    
                    return
                end
            end
            
            -- ACTIVELY dig tunnels regardless of timer
            -- This ensures rovers are always tunneling when in explore mode
            self.last_dig_time = minetest.get_gametime()
            
            -- Always try to dig forward in exploration direction
            local success = self:dig_exploration_tunnel()
            
            -- Log exploration status frequently
            if math.random() < 0.1 then
                minetest.log("action", "[ROVER MOD] ACTIVELY EXPLORING in direction " .. 
                    minetest.pos_to_string(self.explore_dir) .. 
                    ", distance: " .. (self.explore_distance or 0))
            end
            
            if not success then
                -- If we can't go forward, turn EXACTLY 90 degrees
                self:change_direction()
                
                -- Log direction change
                minetest.log("action", "[ROVER MOD] Rover hit obstacle, turning EXACTLY 90 degrees to " .. 
                    minetest.pos_to_string(self.explore_dir))
            end
            
            -- The turning is now handled in the dig_exploration_tunnel function
            -- at exactly 10-block intervals
            
            -- Random small chance to detect ice even beyond normal range (simulating larger scans)
            if math.random() < 0.01 then  -- 1% chance
                local super_scan_radius = self.ice_search_radius * 1.5
                local far_ice_pos = find_nearest_node(self.object:get_pos(), "ice_rock", super_scan_radius)
                
                if far_ice_pos then
                    -- Detected distant ice, aim in that general direction
                    local pos = self.object:get_pos()
                    local dir_to_ice = vector.direction(pos, far_ice_pos)
                    
                    -- Determine which cardinal direction is closest to the ice direction
                    local cardinal_dirs = {
                        {x=1, y=0, z=0},   -- East
                        {x=-1, y=0, z=0},  -- West
                        {x=0, y=0, z=1},   -- North
                        {x=0, y=0, z=-1}   -- South
                    }
                    
                    local best_dot = -1
                    local best_dir = nil
                    
                    for _, cdir in ipairs(cardinal_dirs) do
                        local dot = dir_to_ice.x * cdir.x + dir_to_ice.z * cdir.z
                        if dot > best_dot then
                            best_dot = dot
                            best_dir = cdir
                        end
                    end
                    
                    if best_dir and (best_dir.x ~= self.explore_dir.x or best_dir.z ~= self.explore_dir.z) then
                        -- Change to the direction most aligned with the ice
                        self.explore_dir = best_dir
                        
                        -- Set facing direction based on new exploration vector
                        local yaw = minetest.dir_to_yaw(self.explore_dir)
                        self.object:set_yaw(yaw)
                        
                        -- Reset distance counter for the new direction
                        self.explore_distance = 0
                        
                        minetest.log("action", "[ROVER MOD] Rover detected faint ice signature, " ..
                            "changing direction toward potential ice")
                    end
                end
            end
            
        elseif self.state == "MINE" then
            -- If we have a target resource node, move toward it
            if self.target_pos then
                -- First, ensure we're not trying to mine downward
                if self.target_pos.y < pos.y then
                    self.target_pos.y = pos.y
                    minetest.log("action", "[ROVER MOD] Corrected mining target to horizontal level")
                end
                
                -- Calculate direct distance but only consider horizontal component
                local horizontal_dist = math.sqrt(
                    (pos.x - self.target_pos.x)^2 + 
                    (pos.z - self.target_pos.z)^2
                )
                
                -- Log the targeting regularly
                if math.random() < 0.1 then
                    minetest.log("action", "[ROVER MOD] Mining target is " .. 
                        horizontal_dist .. " blocks away at " .. 
                        minetest.pos_to_string(self.target_pos))
                end
                
                if horizontal_dist < 1.2 then
                    -- We're at the resource, mine it
                    local node = minetest.get_node(self.target_pos)
                    
                    -- Store what we found
                    if minetest.get_item_group(node.name, "regolith") > 0 then
                        self.inventory.regolith = self.inventory.regolith + 1
                    elseif minetest.get_item_group(node.name, "metal_ore") > 0 then
                        self.inventory.metal = self.inventory.metal + 1
                    elseif minetest.get_item_group(node.name, "ice_rock") > 0 then
                        self.inventory.ice = self.inventory.ice + 1
                        
                        -- Log special message for ice discovery
                        minetest.log("action", "[ROVER MOD] ICE COLLECTED! Rover at " .. 
                            minetest.pos_to_string(pos) .. " has collected water ice.")
                    end
                    
                    -- Dig the node, with probability based on mining_rate
                    local mining_rate = (self.traits and self.traits.mining_rate) or 1.0
                    
                    -- Always successful with high mining_rate, chance of failure with lower rate
                    if math.random() <= mining_rate then
                        minetest.dig_node(self.target_pos)
                        
                        -- Record success for evolution tracking
                        if moon_genetics and moon_genetics.record_efficiency then
                            local resource_type = nil
                            if minetest.get_item_group(node.name, "regolith") > 0 then resource_type = "regolith"
                            elseif minetest.get_item_group(node.name, "metal_ore") > 0 then resource_type = "metal"
                            elseif minetest.get_item_group(node.name, "ice_rock") > 0 then resource_type = "ice"
                            end
                            
                            if resource_type then
                                moon_genetics.record_efficiency(self, resource_type, 1)
                            end
                        end
                        
                        -- Switch to return state - use path history if coming from EXPLORE
                        self.state = "RETURN"
                        self.target_pos = nil
                    else
                        -- Mining failed, try again next step
                        -- Visual effect for failed attempt
                        minetest.add_particlespawner({
                            amount = 5,
                            time = 0.5,
                            minpos = {x=self.target_pos.x-0.2, y=self.target_pos.y, z=self.target_pos.z-0.2},
                            maxpos = {x=self.target_pos.x+0.2, y=self.target_pos.y+0.3, z=self.target_pos.z+0.2},
                            minvel = {x=-0.5, y=0.5, z=-0.5},
                            maxvel = {x=0.5, y=1, z=0.5},
                            minacc = {x=0, y=0, z=0},
                            maxacc = {x=0, y=0, z=0},
                            minexptime = 0.5,
                            maxexptime = 1,
                            minsize = 1,
                            maxsize = 2,
                            collisiondetection = false,
                            texture = "moon_regolith.png",
                        })
                    end
                else
                    -- Move toward target (strictly horizontally)
                    local dir = vector.direction(pos, self.target_pos)
                    
                    -- Force horizontal movement only - zero out the Y component
                    local horizontal_dir = {
                        x = dir.x,
                        y = 0,  -- Force no vertical movement
                        z = dir.z
                    }
                    
                    -- Calculate yaw for horizontal movement only
                    local yaw = minetest.dir_to_yaw(horizontal_dir)
                    self.object:set_yaw(yaw)
                    
                    -- Add current position to path if moving toward ice
                    if minetest.get_item_group(minetest.get_node(self.target_pos).name, "ice_rock") > 0 
                       and math.random() < 0.2 then  -- Only record some waypoints to save memory
                        local rounded_pos = {
                            x = math.floor(pos.x + 0.5),
                            y = math.floor(pos.y + 0.5),
                            z = math.floor(pos.z + 0.5)
                        }
                        table.insert(self.path_history, rounded_pos)
                    end
                    
                    -- Set velocity toward target - STRICTLY HORIZONTAL
                    self.object:set_velocity({
                        x = horizontal_dir.x * 0.5 * self:get_speed_factor(),
                        y = 0,  -- Explicitly force no vertical movement
                        z = horizontal_dir.z * 0.5 * self:get_speed_factor(),
                    })
                    
                    -- Set zero acceleration to prevent gravity
                    self.object:set_acceleration({x=0, y=0, z=0})
                    
                    -- If the target is below us, refuse to go down
                    if self.target_pos.y < pos.y then
                        -- Override with a horizontal-only target
                        self.target_pos.y = pos.y
                        minetest.log("action", "[ROVER MOD] Forced target to horizontal level - no digging down!")
                    end
                    
                    -- Log that we're moving horizontally toward target
                    if math.random() < 0.01 then  -- Only log occasionally
                        minetest.log("action", "[ROVER MOD] Moving HORIZONTALLY toward target resource")
                    end
                end
            else
                -- No target, go back to search
                self.state = "SEARCH"
            end
            
        elseif self.state == "RETURN" then
            -- Special handling when carrying ice (high-priority resource)
            if self.inventory.ice > 0 then
                -- Prioritize careful backtracking when carrying ice
                if #self.path_history > 0 then
                    -- We have a path history with ice - backtrack exactly the way we came
                    -- This is the most reliable way to return with ice
                    local success = self:backtrack()
                    
                    -- Add dramatic visual effect for carrying ice
                    if math.random() < 0.1 then  -- occasional particle effect for ice
                        minetest.add_particlespawner({
                            amount = 3,
                            time = 0.3,
                            minpos = {x=pos.x-0.2, y=pos.y+0.2, z=pos.z-0.2},
                            maxpos = {x=pos.x+0.2, y=pos.y+0.4, z=pos.z+0.2},
                            minvel = {x=0, y=0, z=0},
                            maxvel = {x=0, y=0.01, z=0},
                            minacc = {x=0, y=0, z=0},
                            maxacc = {x=0, y=0, z=0},
                            minexptime = 1.0,
                            maxexptime = 1.5,
                            minsize = 1,
                            maxsize = 2,
                            collisiondetection = false,
                            texture = "bubble.png^[colorize:#00FFFF:127",
                        })
                    end
                    
                    if not success then
                        -- Reached the end of our backtrack path
                        -- Now find the nearest hub
                        local nest_pos = find_nearest_nest(pos, 25)  -- Increased search radius for ice
                        
                        if nest_pos then
                            -- We found a hub, move toward it
                            local dir = vector.direction(pos, nest_pos)
                            local yaw = minetest.dir_to_yaw(dir)
                            self.object:set_yaw(yaw)
                            
                            -- Set velocity toward hub - move faster with ice (emergency priority)
                            local speed_boost = 1.2  -- 20% speed boost with ice
                            self.object:set_velocity({
                                x = dir.x * 0.5 * self:get_speed_factor() * speed_boost,
                                y = 0,
                                z = dir.z * 0.5 * self:get_speed_factor() * speed_boost,
                            })
                            
                            -- Log the final approach with ice
                            minetest.log("action", "[ROVER MOD] Backtracking complete, approaching hub with ice")
                        else
                            -- No nest found, but we need to deliver this ice!
                            -- Let's search in a wandering pattern
                            minetest.log("action", "[ROVER MOD] No hub visible! Seeking delivery location for ice")
                            
                            -- Choose a random direction to search
                            local yaw = math.random() * math.pi * 2
                            self.object:set_yaw(yaw)
                            
                            -- Move at half speed to scan for hub
                            self.object:set_velocity({
                                x = math.cos(yaw) * 0.3 * self:get_speed_factor(),
                                y = 0,
                                z = math.sin(yaw) * 0.3 * self:get_speed_factor(),
                            })
                        end
                    end
                else
                    -- No path history (direct mining) but still have ice - find nearest hub
                    local nest_pos = find_nearest_nest(pos, 25)  -- Increased search radius for ice
                    
                    if nest_pos then
                        -- We found a hub, move toward it
                        local dist = vector.distance(pos, nest_pos)
                        
                        if dist < 1.5 then
                            -- We've reached the hub, deposit resources with special handling for ice
                            self:deposit_resources(nest_pos)
                        else
                            -- Move toward hub - faster when carrying ice
                            local dir = vector.direction(pos, nest_pos)
                            local yaw = minetest.dir_to_yaw(dir)
                            self.object:set_yaw(yaw)
                            
                            -- Speed boost for ice delivery
                            local speed_boost = 1.2  -- 20% speed boost
                            self.object:set_velocity({
                                x = dir.x * 0.5 * self:get_speed_factor() * speed_boost,
                                y = 0,
                                z = dir.z * 0.5 * self:get_speed_factor() * speed_boost,
                            })
                        end
                    else
                        -- No hub in range, keep searching
                        self.state = "SEARCH"
                        minetest.log("action", "[ROVER MOD] No hub in range! Continuing search with ice cargo.")
                    end
                end
            else
                -- Standard return behavior for non-ice resources
                local nest_pos = find_nearest_nest(pos, 20)
                
                if nest_pos then
                    -- We found a hub, move toward it
                    local dist = vector.distance(pos, nest_pos)
                    
                    if dist < 1.5 then
                        -- We've reached the hub, deposit resources
                        self:deposit_resources(nest_pos)
                    else
                        -- Move toward hub
                        local dir = vector.direction(pos, nest_pos)
                        local yaw = minetest.dir_to_yaw(dir)
                        self.object:set_yaw(yaw)
                        
                        -- Set velocity toward hub
                        self.object:set_velocity({
                            x = dir.x * 0.5 * self:get_speed_factor(),
                            y = 0,
                            z = dir.z * 0.5 * self:get_speed_factor(),
                        })
                    end
                else
                    -- No nest found, go back to searching
                    self.state = "SEARCH"
                end
            end
        end
        
        -- Update nametag with current state
        self:update_nametag()
    end,
    
    on_step = function(self, dtime)
        self.timer = (self.timer or 0) + dtime
        self.move_timer = (self.move_timer or 0) + dtime
        
        -- Run the state machine
        self:step_state(dtime)
        
        -- Occasional status update to log
        if self.timer > 10 then
            self.timer = 0
            local pos = self.object:get_pos()
            local status_info = string.format("[ROVER MOD] Rover at %s, state: %s", 
                minetest.pos_to_string(pos), self.state)
            
            -- Add exploration info if relevant
            if self.state == "EXPLORE" then
                status_info = status_info .. string.format(", direction: %s, distance: %d blocks", 
                    minetest.pos_to_string(self.explore_dir or {x=0,y=0,z=0}),
                    self.explore_distance or 0)
            end
            
            -- Add ice info if carrying
            if self.inventory.ice > 0 then
                status_info = status_info .. ", carrying ice: " .. self.inventory.ice
            end
            
            minetest.log("action", status_info)
        end
    end,
    
    -- Add a punch handler for debugging
    on_punch = function(self, puncher, time_from_last_punch, tool_capabilities, dir)
        minetest.log("action", "[ROVER MOD] Rover diagnostics requested")
        local inv_text = string.format("Silicon: %d, Metal: %d, Water-Ice: %d", 
            self.inventory.regolith, self.inventory.metal, self.inventory.ice)
            
        -- Show specifications if available
        local specs_text = ""
        if self.traits then
            specs_text = string.format("\nSpecifications:\n * Propulsion Rate: %.2f\n * Drill Efficiency: %.2f\n * Scanner Range: %.1f\n * Cargo Capacity: %.1f", 
                self.traits.speed or 0.5,
                self.traits.mining_rate or 1.0,
                self.traits.search_radius or 8.0,
                self.traits.carrying_capacity or 1.0)
            
            if self.traits.radiation_resist and self.traits.radiation_resist > 0 then
                specs_text = specs_text .. string.format("\n * Radiation Shielding: %.1f%%", self.traits.radiation_resist * 100)
            end
            
            if self.traits.cold_resist and self.traits.cold_resist > 0 then
                specs_text = specs_text .. string.format("\n * Thermal Insulation: %.1f%%", self.traits.cold_resist * 100)
            end
            
            if self.traits.energy_efficiency then
                specs_text = specs_text .. string.format("\n * Power Efficiency: %.2f", self.traits.energy_efficiency)
            end
            
            specs_text = specs_text .. string.format("\n * Ice Detection Range: %.1f", self.ice_search_radius or 20.0)
        end
        
        -- Add exploration info if in explore mode
        local mission_text = ""
        if self.state == "EXPLORE" then
            local direction_str = "none"
            if self.explore_dir then
                if self.explore_dir.x > 0 then direction_str = "East"
                elseif self.explore_dir.x < 0 then direction_str = "West"
                elseif self.explore_dir.z > 0 then direction_str = "North"
                elseif self.explore_dir.z < 0 then direction_str = "South"
                end
            end
            
            mission_text = string.format("\n\nExploration Mission:\n * Direction: %s\n * Distance: %d blocks\n * Path History: %d points stored",
                direction_str, 
                self.explore_distance or 0,
                #self.path_history)
        end
        
        minetest.chat_send_player(puncher:get_player_name(), 
            "Rover Unit Status: " .. self.state .. "\nCargo Hold: " .. inv_text .. specs_text .. mission_text)
        return true
    end,
})

-- Add a rover deployment tool for testing
minetest.register_craftitem("moon:ant_spawn_egg", {
    description = "Rover Deployment Unit",
    inventory_image = "default_sand.png^[colorize:#00AAFF:50",
    on_place = function(itemstack, placer, pointed_thing)
        if pointed_thing.type ~= "node" then
            return itemstack
        end
        
        local pos = pointed_thing.above
        pos.y = pos.y + 0.5 -- Raise slightly above ground
        
        minetest.log("action", "[ROVER MOD] Deploying rover unit at " .. 
            minetest.pos_to_string(pos))
        minetest.add_entity(pos, "moon:ant")
        minetest.chat_send_player(placer:get_player_name(), 
            "Rover unit deployed at " .. minetest.pos_to_string(pos))
        
        if not minetest.is_creative_enabled(placer:get_player_name()) then
            itemstack:take_item()
        end
        
        return itemstack
    end,
})

-- Deploy rovers on command
minetest.register_chatcommand("deployunit", {
    description = "Deploy a rover unit at your position",
    func = function(name, param)
        local player = minetest.get_player_by_name(name)
        if not player then return false, "Player not found" end
        
        local pos = player:get_pos()
        pos.y = pos.y + 1
        
        minetest.add_entity(pos, "moon:ant")
        return true, "Rover unit deployed at " .. minetest.pos_to_string(pos)
    end,
})

-- Automatic ant spawning near regolith (DISABLED)
-- We'll rely only on initial spawn to avoid too many ants
--[[ 
minetest.register_abm({
    label = "Spawn Moon Ants",
    nodenames = {"moon:regolith"},
    interval = 60, -- Check every minute (much slower)
    chance = 200, -- 0.5% chance per check (much lower)
    action = function(pos, node)
        -- Check if there are already ants nearby
        local objs = minetest.get_objects_inside_radius(pos, 20)
        local ant_count = 0
        
        for _, obj in ipairs(objs) do
            local ent = obj:get_luaentity()
            if ent and ent.name == "moon:ant" then
                ant_count = ant_count + 1
            end
        end
        
        -- Don't spawn too many ants in one area and check global count
        if ant_count < 3 then
            local spawn_pos = {
                x = pos.x + math.random(-3, 3),
                y = pos.y + 1,
                z = pos.z + math.random(-3, 3)
            }
            
            -- Make sure we're spawning in air
            if minetest.get_node(spawn_pos).name == "air" then
                minetest.log("action", "[ANTS MOD] Spawning ant at " .. 
                    minetest.pos_to_string(spawn_pos))
                minetest.add_entity(spawn_pos, "moon:ant")
            end
        end
    end,
})
--]]

-- Deploy initial rover units when a player joins the game
minetest.register_on_joinplayer(function(player)
    minetest.log("action", "[ROVER MOD] Player joined, deploying initial rover units")
    
    -- Delay slightly to make sure the player is fully loaded
    minetest.after(2, function()
        local player_pos = player:get_pos()
        
        -- Deploy 5 rover units around the player
        for i = 1, 5 do
            local deploy_pos = {
                x = player_pos.x + math.random(-10, 10),
                y = player_pos.y + 1,
                z = player_pos.z + math.random(-10, 10)
            }
            
            -- Make sure we're deploying on a clear area
            if minetest.get_node(deploy_pos).name == "air" then
                minetest.log("action", "[ROVER MOD] Deploying initial rover at " .. 
                    minetest.pos_to_string(deploy_pos))
                minetest.add_entity(deploy_pos, "moon:ant")
            else
                -- If we can't deploy at the random location, deploy closer to player
                deploy_pos = {
                    x = player_pos.x + math.random(-3, 3),
                    y = player_pos.y + 1,
                    z = player_pos.z + math.random(-3, 3)
                }
                minetest.log("action", "[ROVER MOD] Deploying initial rover (fallback) at " .. 
                    minetest.pos_to_string(deploy_pos))
                minetest.add_entity(deploy_pos, "moon:ant")
            end
        end
        
        -- Let the player know about the rovers
        minetest.chat_send_player(player:get_player_name(), 
            "Welcome to the lunar surface! Resource collection rovers have been deployed.")
    end)
end)

-- Debug tool - to count active units
minetest.register_chatcommand("countunits", {
    description = "Count rover units in the area",
    func = function(name, param)
        local player = minetest.get_player_by_name(name)
        if not player then return false, "Player not found" end
        
        local pos = player:get_pos()
        local radius = tonumber(param) or 20
        
        local objs = minetest.get_objects_inside_radius(pos, radius)
        local rover_count = 0
        local states = {SEARCH = 0, EXPLORE = 0, MINE = 0, RETURN = 0}
        local ice_carriers = 0
        
        for _, obj in ipairs(objs) do
            local ent = obj:get_luaentity()
            if ent and ent.name == "moon:ant" then
                rover_count = rover_count + 1
                
                -- Count rovers by state
                if ent.state then
                    states[ent.state] = (states[ent.state] or 0) + 1
                end
                
                -- Count rovers carrying ice
                if ent.inventory and ent.inventory.ice and ent.inventory.ice > 0 then
                    ice_carriers = ice_carriers + 1
                end
            end
        end
        
        local state_report = string.format("Rover states: Search=%d, Explore=%d, Mine=%d, Return=%d", 
            states.SEARCH or 0, states.EXPLORE or 0, states.MINE or 0, states.RETURN or 0)
        
        local ice_report = ""
        if ice_carriers > 0 then
            ice_report = "\n" .. ice_carriers .. " rovers are carrying water ice! (" .. 
                         math.floor(ice_carriers / rover_count * 100) .. "% of total)"
        end
        
        return true, "Located " .. rover_count .. " rover units within " .. radius .. 
               " meter radius\n" .. state_report .. ice_report
    end,
})

-- Enhanced command to locate ice in the area
minetest.register_chatcommand("findice", {
    description = "Search for ice deposits in the area",
    func = function(name, param)
        local player = minetest.get_player_by_name(name)
        if not player then return false, "Player not found" end
        
        local pos = player:get_pos()
        local radius = tonumber(param) or 30
        
        -- Find all ice nodes in area
        local minp = {x=pos.x-radius, y=pos.y-radius, z=pos.z-radius}
        local maxp = {x=pos.x+radius, y=pos.y+radius, z=pos.z+radius}
        local ice_nodes = minetest.find_nodes_in_area(minp, maxp, {"moon:ice_rock", "default:ice"})
        
        if #ice_nodes == 0 then
            return true, "No ice deposits detected within " .. radius .. " meter radius."
        end
        
        -- Find closest deposit
        local closest_dist = radius * 2  -- Initialize with value larger than possible
        local closest_pos = nil
        
        for _, ice_pos in ipairs(ice_nodes) do
            local dist = vector.distance(pos, ice_pos)
            if dist < closest_dist then
                closest_dist = dist
                closest_pos = ice_pos
            end
        end
        
        -- Create a homing particle trail to the closest ice
        if closest_pos then
            -- Make ice location more visible
            for i = 1, 5 do
                minetest.after(i * 0.5, function()
                    minetest.add_particlespawner({
                        amount = 30,
                        time = 1.0,
                        minpos = {x=closest_pos.x-0.5, y=closest_pos.y-0.5, z=closest_pos.z-0.5},
                        maxpos = {x=closest_pos.x+0.5, y=closest_pos.y+0.5, z=closest_pos.z+0.5},
                        minvel = {x=-0.5, y=0.5, z=-0.5},
                        maxvel = {x=0.5, y=1.5, z=0.5},
                        minacc = {x=0, y=0, z=0},
                        maxacc = {x=0, y=0, z=0},
                        minexptime = 1,
                        maxexptime = 2,
                        minsize = 2,
                        maxsize = 4,
                        collisiondetection = false,
                        texture = "bubble.png^[colorize:#00FFFF:127",
                    })
                end)
            end
            
            -- Create a waypoint arrow to show direction
            local dir = vector.direction(pos, closest_pos)
            local distance = vector.distance(pos, closest_pos)
            
            return true, string.format(
                "Located %d ice deposits within %d meter radius!\nNearest deposit: %d meters %s at %s", 
                #ice_nodes, 
                radius,
                math.floor(distance),
                get_direction_name(dir),
                minetest.pos_to_string(closest_pos)
            )
        else
            return true, "Found " .. #ice_nodes .. " ice deposits, but couldn't determine closest."
        end
    end,
})

-- Helper function to get a cardinal direction name from a direction vector
function get_direction_name(dir)
    local x, z = dir.x, dir.z
    local x_abs, z_abs = math.abs(x), math.abs(z)
    
    if x_abs > z_abs * 2 then
        return x > 0 and "East" or "West"
    elseif z_abs > x_abs * 2 then
        return z > 0 and "North" or "South"
    else
        if x > 0 and z > 0 then return "Northeast"
        elseif x > 0 and z < 0 then return "Southeast"
        elseif x < 0 and z > 0 then return "Northwest"
        else return "Southwest" end
    end
end

minetest.log("action", "[ROVER MOD] Lunar resource rover module fully loaded")
