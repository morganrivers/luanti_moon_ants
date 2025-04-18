minetest.register_entity("moon:ant", {
    initial_properties = {
        physical = true,
        collide_with_objects = true,
        collisionbox = {-0.3, -0.01, -0.3, 0.3, 0.25, 0.3},
        visual = "sprite",
        textures = {"ant.png"}, 
        visual_size = {x = 1.2, y = 1.2},
        nametag = "Rover Unit",
        nametag_color = "#00AAFF",
        is_visible = true,
    },
    
    -- Movement and digging variables
    steps_taken = 0,
    current_direction = nil,
    dig_cooldown = 0,
    max_regolith = 3,  -- Maximum carrying capacity before returning
    returning = false, -- Tracks whether rover is returning to hub
    inventory = {regolith = 0, metal = 0, ice = 0},

    -- on_activate = function(self, staticdata)
    --     minetest.log("action", "[ROVER MOD] Rover unit activated")
        
    --     -- Disable gravity
    --     self.object:set_acceleration({x=0, y=-1, z=0})
        
    --     -- Choose initial direction
    --     self:choose_initial_direction()
    -- end,
    on_activate = function(self, staticdata)
        minetest.log("action", "[ROVER MOD] Rover unit activated")
        
        -- Use a gentler gravity
        self.object:set_acceleration({x=0, y=-1, z=0})
        
        -- Set physical properties
        self.object:set_properties({
            physical = true,
            collide_with_objects = true,
            collisionbox = {-0.3, -0.01, -0.3, 0.3, 0.25, 0.3},
        })
        
        -- Choose initial direction
        self:choose_initial_direction()
    end,
    -- Initial random direction
    choose_initial_direction = function(self)
        -- Cardinal directions
        local directions = {
            {x=1, y=0, z=0},   -- East
            {x=-1, y=0, z=0},  -- West
            {x=0, y=0, z=1},   -- North
            {x=0, y=0, z=-1}   -- South
        }
        
        -- Select a random initial direction
        self.current_direction = directions[math.random(1, 4)]
        self.steps_taken = 0
        
        -- Set facing
        local yaw = minetest.dir_to_yaw(self.current_direction)
        self.object:set_yaw(yaw)
        
        minetest.log("action", "[ROVER MOD] Initial direction: " .. 
            minetest.pos_to_string(self.current_direction))
    end,
    
    -- Make a 90-degree turn
    turn_90_degrees = function(self)
        -- Randomly choose left or right turn
        local turn_left = (math.random() > 0.7)
        local new_dir = {}
        
        if turn_left then
            -- Left turn (90° counterclockwise)
            new_dir = {
                x = -self.current_direction.z,
                y = 0,
                z = self.current_direction.x
            }
        else
            -- Right turn (90° clockwise)
            new_dir = {
                x = self.current_direction.z,
                y = 0,
                z = -self.current_direction.x
            }
        end
        
        self.current_direction = new_dir
        self.steps_taken = 0
        
        -- Set facing direction
        local yaw = minetest.dir_to_yaw(self.current_direction)
        self.object:set_yaw(yaw)
        
        minetest.log("action", "[ROVER MOD] 90° turn to " .. 
            minetest.pos_to_string(self.current_direction))
    end,
    -- Keep the rover at a consistent height above ground
    adjust_height = function(self)
        local pos = self.object:get_pos()
        if not pos then return end
        
        -- Check if there's ground below
        local below_pos = {x=pos.x, y=pos.y-0.3, z=pos.z}
        local node_below = minetest.get_node_or_nil(below_pos)
        
        if node_below and node_below.name == "air" then
            -- We're floating, apply gravity
            -- This is already handled by the small gravity value
        else
            -- We're on ground, maintain proper height
            local target_y = math.floor(pos.y) + 0.5
            if math.abs(pos.y - target_y) > 0.1 then
                self.object:set_pos({x=pos.x, y=target_y, z=pos.z})
            end
        end
    end,

    -- -- Keep the rover at a consistent height above ground
    -- adjust_height = function(self)
    --     local pos = self.object:get_pos()
    --     if not pos then return end
        
    --     -- Check if there's ground below
    --     local below_pos = {x=pos.x, y=pos.y-0.5, z=pos.z}
    --     local node_below = minetest.get_node_or_nil(below_pos)
        
    --     if node_below and node_below.name ~= "air" then
    --         -- We're above ground, adjust to proper height
    --         local target_y = math.floor(pos.y) + 0.5
    --         self.object:set_pos({x=pos.x, y=target_y, z=pos.z})
    --     end
    -- end,

    -- -- Dig a block in current movement direction
    -- dig_block = function(self)
    --     local pos = self.object:get_pos()
    --     if not pos then return false end
        
    --     -- Round to nearest block center
    --     pos = {
    --         x = math.floor(pos.x + 0.5),
    --         y = math.floor(pos.y + 0.5),
    --         z = math.floor(pos.z + 0.5)
    --     }
        
    --     -- Calculate target position in front of rover
    --     local front_pos = {
    --         x = pos.x + self.current_direction.x,
    --         y = pos.y,  -- Keep y position the same (horizontal movement)
    --         z = pos.z + self.current_direction.z
    --     }
        
    --     -- Check if the block is diggable
    --     local node = minetest.get_node(front_pos)
    --     if node and node.name ~= "air" then
    --         -- Block types that can be dug (adjust as needed for your game)
    --         local diggable = (node.name == "moon:regolith" or 
    --                          node.name == "default:stone" or 
    --                          node.name == "moon:bedrock")
    --         -- Inside the dig_block function where digging happens
    --         if diggable then
    --             -- Dig the block
    --             minetest.dig_node(front_pos)
                
    --             -- Add regolith to inventory (most blocks are regolith)
    --             self.inventory.regolith = self.inventory.regolith + 1
                
    --             -- Add particle effects for drilling
    --             minetest.add_particlespawner({
    --                 amount = 10,
    --                 time = 0.5,
    --                 minpos = {x=front_pos.x-0.2, y=front_pos.y, z=front_pos.z-0.2},
    --                 maxpos = {x=front_pos.x+0.2, y=front_pos.y+0.3, z=front_pos.z+0.2},
    --                 minvel = {x=-0.5, y=0.5, z=-0.5},
    --                 maxvel = {x=0.5, y=1, z=0.5},
    --                 minacc = {x=0, y=0, z=0},
    --                 maxacc = {x=0, y=0, z=0},
    --                 minexptime = 0.5,
    --                 maxexptime = 1,
    --                 minsize = 1,
    --                 maxsize = 2,
    --                 collisiondetection = false,
    --                 texture = "moon_regolith.png",
    --             })                
    --             -- Move into the dug area
    --             self.object:set_pos(front_pos)
                
    --             -- Increment steps and check for turn
    --             self.steps_taken = self.steps_taken + 1
                
    --             -- Check if inventory is full and should return
    --             if self.inventory.regolith >= self.max_regolith then
    --                 -- Switch to return mode
    --                 self.returning = true
    --             else
    --                 -- Turn after 10 steps (if not full)
    --                 if self.steps_taken >= 10 then
    --                     self:turn_90_degrees()
    --                 end
    --             end
                
    --             return true
    --         end
    --     elseif node and node.name == "air" then
    --         -- If the space is already clear, move forward
    --         self.object:set_pos(front_pos)
            
    --         -- Increment steps and check for turn
    --         self.steps_taken = self.steps_taken + 1
            
    --         -- Turn after 10 steps
    --         if self.steps_taken >= 10 then
    --             self:turn_90_degrees()
    --         end
            
    --         return true
    --     end
        
    --     -- If we can't dig or move forward, turn
    --     self:turn_90_degrees()
    --     return false
    -- end,
    -- Enhanced dig_block with climbing capabilities
    -- Modified dig_block with climb-first strategy
    dig_block = function(self)
        local pos = self.object:get_pos()
        if not pos then return false end
        
        -- Round to nearest block center
        pos = {
            x = math.floor(pos.x + 0.5),
            y = math.floor(pos.y + 0.5),
            z = math.floor(pos.z + 0.5)
        }
        
        -- Calculate target position in front of rover
        local front_pos = {
            x = pos.x + self.current_direction.x,
            y = pos.y,  -- Same level
            z = pos.z + self.current_direction.z
        }
        
        -- Try to move on the same level first if path is clear
        local node = minetest.get_node(front_pos)
        if node and node.name == "air" then
            -- Path is clear, move forward
            self.object:set_pos(front_pos)
            self.steps_taken = self.steps_taken + 1
            
            -- Check for turn condition
            if self.steps_taken >= 10 and not self.returning then
                self:turn_90_degrees()
            end
            return true
        end
        
        -- Path is blocked - first try to climb up (prioritize climbing over digging)
        local up_front_pos = {
            x = front_pos.x,
            y = front_pos.y + 1,  -- One block higher
            z = front_pos.z
        }
        
        local node_up_front = minetest.get_node(up_front_pos)
        local node_above = minetest.get_node({x=pos.x, y=pos.y+1, z=pos.z})
        
        -- Check if we can climb up (need free space at head level and in front)
        if node_up_front.name == "air" and node_above.name == "air" then
            -- We can climb up - there's space for us to move up and forward
            self.object:set_pos(up_front_pos)
            self.steps_taken = self.steps_taken + 1
            
            -- Check turn condition
            if self.steps_taken >= 10 and not self.returning then
                self:turn_90_degrees()
            end
            return true
        end
        
        -- If we can't climb naturally, try digging up to create a path
        if node_up_front.name ~= "air" then
            local diggable_up = (node_up_front.name == "moon:regolith" or 
                              node_up_front.name == "default:stone" or 
                              node_up_front.name == "moon:bedrock" or
                              node_up_front.name == "moon:metal_ore" or
                              node_up_front.name == "moon:ice_rock")
            
            -- Also check the block above our head
            local diggable_above = false
            if node_above.name ~= "air" then
                diggable_above = (node_above.name == "moon:regolith" or 
                                node_above.name == "default:stone" or 
                                node_above.name == "moon:bedrock" or
                                node_above.name == "moon:metal_ore" or
                                node_above.name == "moon:ice_rock")
            end
            
            -- If both blocks are diggable, create a path upward
            if diggable_up and (node_above.name == "air" or diggable_above) then
                -- Save the node type before digging
                local up_front_node_name = node_up_front.name
                
                -- Dig the block in front at higher level
                minetest.dig_node(up_front_pos)
                
                -- Check what resource we collected from upward dig
                if up_front_node_name == "moon:metal_ore" then
                    self.inventory.metal = self.inventory.metal + 1
                elseif up_front_node_name == "moon:ice_rock" then
                    self.inventory.ice = self.inventory.ice + 1
                else
                    -- Normal regolith or stone
                    self.inventory.regolith = self.inventory.regolith + 1
                end
                
                -- Dig the block above us if needed
                if node_above.name ~= "air" then
                    local above_node_name = node_above.name
                    minetest.dig_node({x=pos.x, y=pos.y+1, z=pos.z})
                    
                    -- Check what resource we collected from above head
                    if above_node_name == "moon:metal_ore" then
                        self.inventory.metal = self.inventory.metal + 1
                    elseif above_node_name == "moon:ice_rock" then
                        self.inventory.ice = self.inventory.ice + 1
                    else
                        -- Normal regolith or stone
                        self.inventory.regolith = self.inventory.regolith + 1
                    end
                end
                
                -- Add particles for digging
                minetest.add_particlespawner({
                    amount = 15,
                    time = 0.5,
                    minpos = {x=up_front_pos.x-0.2, y=up_front_pos.y-0.2, z=up_front_pos.z-0.2},
                    maxpos = {x=up_front_pos.x+0.2, y=up_front_pos.y+0.2, z=up_front_pos.z+0.2},
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
                
                -- Climb up and forward
                self.object:set_pos(up_front_pos)
                self.steps_taken = self.steps_taken + 1
                
                -- Check inventory and turn conditions
                if self.inventory.regolith + self.inventory.metal + self.inventory.ice >= self.max_regolith then
                    self.returning = true
                elseif self.steps_taken >= 10 and not self.returning then
                    self:turn_90_degrees()
                end
                
                return true
            end
        end
        
        -- If we can't climb up, then try to dig forward on the same level
        if node and node.name ~= "air" then
            local diggable = (node.name == "moon:regolith" or 
                             node.name == "default:stone" or 
                             node.name == "moon:bedrock" or
                             node.name == "moon:metal_ore" or
                             node.name == "moon:ice_rock")
            
            if diggable then
                -- Save the node type before digging
                local node_name = node.name
                
                -- Dig the block
                minetest.dig_node(front_pos)
                
                -- Check what resource we collected
                if node_name == "moon:metal_ore" then
                    self.inventory.metal = self.inventory.metal + 1
                elseif node_name == "moon:ice_rock" then
                    self.inventory.ice = self.inventory.ice + 1
                else
                    -- Normal regolith or stone
                    self.inventory.regolith = self.inventory.regolith + 1
                end
                
                -- Add particle effects
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
                
                -- Move into the dug area
                self.object:set_pos(front_pos)
                self.steps_taken = self.steps_taken + 1
                
                -- Check inventory and turn conditions
                if self.inventory.regolith + self.inventory.metal + self.inventory.ice >= self.max_regolith then
                    self.returning = true
                elseif self.steps_taken >= 10 and not self.returning then
                    self:turn_90_degrees()
                end
                
                return true
            end
        end
        
        -- If digging failed and we have blocks, try to place a block to create stairs
        if self.inventory.regolith > 0 and not self.returning then
            return self:place_block_for_climbing()
        end
        
        -- If all else fails, try turning
        self:turn_90_degrees()
        return false
    end,


    -- Place a block to create a stairway for climbing
    place_block_for_climbing = function(self)
        local pos = self.object:get_pos()
        if not pos then return false end
        
        -- Round to nearest block center
        pos = {
            x = math.floor(pos.x + 0.5),
            y = math.floor(pos.y + 0.5),
            z = math.floor(pos.z + 0.5)
        }
        
        -- Calculate target position in front of rover
        local front_pos = {
            x = pos.x + self.current_direction.x,
            y = pos.y,  -- Same level
            z = pos.z + self.current_direction.z
        }
        
        -- Check if the space is air (we can place a block)
        local node = minetest.get_node(front_pos)
        if node.name == "air" then
            -- Also check if there's something solid below
            local below_pos = {x=front_pos.x, y=front_pos.y-1, z=front_pos.z}
            local node_below = minetest.get_node(below_pos)
            
            -- Only place if there's a solid block below (no floating blocks)
            if node_below.name ~= "air" then
                -- Place regolith block
                minetest.set_node(front_pos, {name="moon:regolith"})
                
                -- Use one block from inventory
                self.inventory.regolith = self.inventory.regolith - 1
                
                -- Add particle effect for placing
                minetest.add_particlespawner({
                    amount = 8,
                    time = 0.3,
                    minpos = {x=front_pos.x-0.3, y=front_pos.y-0.3, z=front_pos.z-0.3},
                    maxpos = {x=front_pos.x+0.3, y=front_pos.y+0.3, z=front_pos.z+0.3},
                    minvel = {x=-0.1, y=0.1, z=-0.1},
                    maxvel = {x=0.1, y=0.3, z=0.1},
                    minacc = {x=0, y=0, z=0},
                    maxacc = {x=0, y=0, z=0},
                    minexptime = 0.3,
                    maxexptime = 0.6,
                    minsize = 1,
                    maxsize = 2,
                    collisiondetection = false,
                    texture = "moon_regolith.png",
                })
                
                minetest.log("action", "[ROVER MOD] Rover placed a block to create a path")
                
                -- Now we can check if we can climb
                local up_front_pos = {x=front_pos.x, y=front_pos.y+1, z=front_pos.z}
                
                -- Make sure there's headroom
                local node_up_front = minetest.get_node(up_front_pos)
                if node_up_front.name == "air" then
                    -- Now check if there's headroom above us
                    local node_above = minetest.get_node({x=pos.x, y=pos.y+1, z=pos.z})
                    
                    if node_above.name == "air" then
                        -- We can climb up - there's space for us
                        self.object:set_pos(up_front_pos)
                        self.steps_taken = self.steps_taken + 1
                        
                        -- Check turn condition
                        if self.steps_taken >= 10 and not self.returning then
                            self:turn_90_degrees()
                        end
                        
                        return true
                    else
                        -- Need to dig above us first
                        local diggable = (node_above.name == "moon:regolith" or 
                                        node_above.name == "default:stone" or 
                                        node_above.name == "moon:bedrock")
                        
                        if diggable then
                            minetest.dig_node({x=pos.x, y=pos.y+1, z=pos.z})
                            self.inventory.regolith = self.inventory.regolith + 1
                            
                            -- Now we can climb
                            self.object:set_pos(up_front_pos)
                            self.steps_taken = self.steps_taken + 1
                            
                            return true
                        end
                    end
                end
            end
        end
        
        return false
    end,

    find_ice = function(self, radius)
        local pos = self.object:get_pos()
        if not pos then return nil end
        
        radius = radius or 8  -- Default search radius
        local nearest_pos = nil
        local nearest_dist = radius + 1
        
        for x = -radius, radius do
            for y = -radius, radius do
                for z = -radius, radius do
                    local check_pos = vector.add(pos, {x=x, y=y, z=z})
                    local node = minetest.get_node_or_nil(check_pos)
                    
                    if node and node.name == "moon:ice_rock" then
                        local dist = vector.distance(pos, check_pos)
                        if dist < nearest_dist then
                            nearest_dist = dist
                            nearest_pos = check_pos
                        end
                    end
                end
            end
        end
        
        return nearest_pos
    end,

    -- Find metal ore similar to how find_ice works
    find_metal_ore = function(self, radius)
        local pos = self.object:get_pos()
        if not pos then return nil end
        
        radius = radius or 8  -- Default search radius
        local nearest_pos = nil
        local nearest_dist = radius + 1
        
        for x = -radius, radius do
            for y = -radius, radius do
                for z = -radius, radius do
                    local check_pos = vector.add(pos, {x=x, y=y, z=z})
                    local node = minetest.get_node_or_nil(check_pos)
                    
                    if node and node.name == "moon:metal_ore" then
                        local dist = vector.distance(pos, check_pos)
                        if dist < nearest_dist then
                            nearest_dist = dist
                            nearest_pos = check_pos
                        end
                    end
                end
            end
        end
        
        return nearest_pos
    end,

    -- Dig toward metal (nearly identical to dig_toward_ice)
    dig_toward_metal = function(self, metal_pos)
        local pos = self.object:get_pos()
        if not pos then return false end
        
        -- Round to nearest block center
        pos = {
            x = math.floor(pos.x + 0.5),
            y = math.floor(pos.y + 0.5),
            z = math.floor(pos.z + 0.5)
        }
        
        -- Calculate direction to metal
        local dir = vector.direction(pos, metal_pos)
        dir.y = 0  -- Force horizontal movement
        
        -- Simplify to cardinal direction
        local cardinal_dir = {x=0, y=0, z=0}
        if math.abs(dir.x) > math.abs(dir.z) then
            cardinal_dir.x = dir.x > 0 and 1 or -1
        else
            cardinal_dir.z = dir.z > 0 and 1 or -1
        end
        
        -- Set rover direction
        self.current_direction = cardinal_dir
        
        -- Set facing direction
        local yaw = minetest.dir_to_yaw(self.current_direction)
        self.object:set_yaw(yaw)
        
        -- Calculate target position
        local front_pos = {
            x = pos.x + self.current_direction.x,
            y = pos.y,
            z = pos.z + self.current_direction.z
        }
        
        -- Check if the block is diggable
        local node = minetest.get_node(front_pos)
        if node and node.name ~= "air" then
            -- Dig the block
            minetest.dig_node(front_pos)
            
            -- Add particle effects
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
        end
        
        -- Move to the target position
        self.object:set_pos(front_pos)
        return true
    end,

    -- Find nearest nest core (hub)
    find_nearest_hub = function(self, radius)
        local pos = self.object:get_pos()
        if not pos then return nil end
        
        radius = radius or 20  -- Search radius for hubs
        
        -- Search in area around the rover
        local hubs = minetest.find_nodes_in_area(
            {x=pos.x-radius, y=pos.y-radius, z=pos.z-radius},
            {x=pos.x+radius, y=pos.y+radius, z=pos.z+radius},
            {"moon:nest_core"}
        )
        
        if #hubs == 0 then
            return nil
        end
        
        -- Find closest hub
        local closest = nil
        local closest_dist = radius * 2
        
        for _, hub_pos in ipairs(hubs) do
            local dist = vector.distance(pos, hub_pos)
            if dist < closest_dist then
                closest_dist = dist
                closest = hub_pos
            end
        end
        
        return closest
    end,
    
    -- Dig toward ice
    dig_toward_ice = function(self, ice_pos)
        local pos = self.object:get_pos()
        if not pos then return false end
        
        -- Round to nearest block center
        pos = {
            x = math.floor(pos.x + 0.5),
            y = math.floor(pos.y + 0.5),
            z = math.floor(pos.z + 0.5)
        }
        
        -- Calculate direction to ice
        local dir = vector.direction(pos, ice_pos)
        dir.y = 0  -- Force horizontal movement
        
        -- Simplify to cardinal direction (choose the strongest component)
        local cardinal_dir = {x=0, y=0, z=0}
        if math.abs(dir.x) > math.abs(dir.z) then
            cardinal_dir.x = dir.x > 0 and 1 or -1
        else
            cardinal_dir.z = dir.z > 0 and 1 or -1
        end
        
        -- Set rover direction
        self.current_direction = cardinal_dir
        
        -- Set facing direction
        local yaw = minetest.dir_to_yaw(self.current_direction)
        self.object:set_yaw(yaw)
        
        -- Calculate target position in front of rover
        local front_pos = {
            x = pos.x + self.current_direction.x,
            y = pos.y,  -- Keep y position the same (horizontal movement)
            z = pos.z + self.current_direction.z
        }
        
        -- Check if the block is diggable
        local node = minetest.get_node(front_pos)
        if node and node.name ~= "air" then
            -- Dig the block
            minetest.dig_node(front_pos)
            
            -- Add particle effects
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
        end
        
        -- Move to the target position
        self.object:set_pos(front_pos)
        return true
    end,
    
    on_step = function(self, dtime)



        -- Add this to the on_step function, before any other digging logic
        if not self.returning then
            -- Find nearest hub to check resource levels
            local hub_pos = self:find_nearest_hub()
            
            if hub_pos then
                -- Get current resource counts from hub
                local meta = minetest.get_meta(hub_pos)
                local regolith_count = meta:get_int("regolith") or 0
                local metal_count = meta:get_int("metal") or 0
                local ice_count = meta:get_int("ice") or 0
                
                -- Determine which resource is lowest
                local priority_resource = "regolith"
                
                -- Prioritize ice if it's lowest or tied for lowest
                if ice_count <= metal_count and ice_count <= regolith_count then
                    priority_resource = "ice"
                -- Otherwise prioritize metal if it's lowest or tied with regolith
                elseif metal_count <= regolith_count then
                    priority_resource = "metal"
                end
                
                -- Look for the priority resource
                if priority_resource == "ice" then
                    local ice_pos = self:find_ice()
                    if ice_pos then
                        -- Dig toward ice
                        if self:dig_toward_ice(ice_pos) then
                            self.dig_cooldown = 1.0
                            return
                        end
                    end
                elseif priority_resource == "metal" then
                    local metal_pos = self:find_metal_ore()
                    if metal_pos then
                        -- Dig toward metal
                        if self:dig_toward_metal(metal_pos) then
                            self.dig_cooldown = 1.0
                            return
                        end
                    end
                end
            end
        end





        -- Adjust height to follow terrain
        self:adjust_height()

        -- Update digger cooldown
        self.dig_cooldown = math.max(0, (self.dig_cooldown or 0) - dtime)
        
        -- Only dig/move if cooldown has expired (1 second)
        if self.dig_cooldown > 0 then
            return
        end
        
        -- If returning with full inventory, find hub
        if self.returning and self.inventory.regolith > 0 then
            local hub_pos = self:find_nearest_hub()
            
            if hub_pos then
                local pos = self.object:get_pos()
                local dist = vector.distance(pos, hub_pos)
                
                if dist < 1.5 then
                    -- Close enough to deposit resources
                    self:deposit_resources(hub_pos)
                    self.returning = false
                else
                    -- Move toward hub
                    local dir = vector.direction(pos, hub_pos)
                    dir.y = 0  -- Force horizontal movement
                    
                    -- Convert to cardinal direction for movement
                    local cardinal_dir = {x=0, y=0, z=0}
                    if math.abs(dir.x) > math.abs(dir.z) then
                        cardinal_dir.x = dir.x > 0 and 1 or -1
                    else
                        cardinal_dir.z = dir.z > 0 and 1 or -1
                    end
                    
                    -- Update rover direction
                    self.current_direction = cardinal_dir
                    
                    -- Set facing direction
                    local yaw = minetest.dir_to_yaw(self.current_direction)
                    self.object:set_yaw(yaw)
                    
                    -- Dig/move toward hub
                    self:dig_block()
                    
                    -- Set cooldown
                    self.dig_cooldown = 1.0
                end
                return
            else
                -- No hub found, continue normal digging
                self.returning = false
            end
        end
        
        -- Check for ice first
        local ice_pos = self:find_ice()
        
        if ice_pos then
            -- Dig toward ice
            if self:dig_toward_ice(ice_pos) then
                -- Set cooldown to 1 second per digging action
                self.dig_cooldown = 1.0
            end
        else
            -- Normal digging in current direction
            if self:dig_block() then
                -- Set cooldown to 1 second per digging action
                self.dig_cooldown = 1.0
            end
        end
        
        -- Zero velocity while not moving (between digs)
        self.object:set_velocity({x=0, y=0, z=0})
    end,
    on_punch = function(self, puncher, time_from_last_punch, tool_capabilities, dir)
        local steps_text = "Steps in current direction: " .. self.steps_taken
        local inv_text = "Regolith: " .. self.inventory.regolith .. "/" .. self.max_regolith
        
        local dir_name = "Unknown"
        if self.current_direction then
            if self.current_direction.x > 0 then dir_name = "East"
            elseif self.current_direction.x < 0 then dir_name = "West"
            elseif self.current_direction.z > 0 then dir_name = "North"
            elseif self.current_direction.z < 0 then dir_name = "South"
            end
        end
        
        local status = self.returning and "Returning to hub" or "Digging"
        
        local pos = self.object:get_pos()
        local pos_text = "Position: " .. minetest.pos_to_string(pos)
        
        minetest.chat_send_player(puncher:get_player_name(), 
            "Rover Status: " .. status .. "\n" .. 
            inv_text .. "\n" .. 
            steps_text .. "\nDirection: " .. dir_name .. 
            "\n" .. pos_text)
        return true
    end,

    deposit_resources = function(self, hub_pos)
        local meta = minetest.get_meta(hub_pos)
        
        -- Update hub inventory counters
        local regolith = meta:get_int("regolith") + self.inventory.regolith
        local metal = meta:get_int("metal") + self.inventory.metal
        local ice = meta:get_int("ice") + self.inventory.ice
        
        -- Add visual effects for deposit
        minetest.add_particlespawner({
            amount = 10,
            time = 0.5,
            minpos = {x=hub_pos.x-0.5, y=hub_pos.y, z=hub_pos.z-0.5},
            maxpos = {x=hub_pos.x+0.5, y=hub_pos.y+1, z=hub_pos.z+0.5},
            minvel = {x=-0.3, y=0.3, z=-0.3},
            maxvel = {x=0.3, y=0.8, z=0.3},
            minacc = {x=0, y=0, z=0},
            maxacc = {x=0, y=0, z=0},
            minexptime = 0.8,
            maxexptime = 1.5,
            minsize = 1,
            maxsize = 2,
            collisiondetection = false,
            texture = "moon_regolith.png",
        })
        
        -- Store updated values
        meta:set_int("regolith", regolith)
        meta:set_int("metal", metal)
        meta:set_int("ice", ice)
        
        -- Update hub infotext
        local energy = moon_energy and moon_energy.get(hub_pos) or 0
        
        meta:set_string("infotext", string.format(
            "Fabrication Hub\nRegolith: %d\nMetal: %d\nIce: %d\nEnergy: %d EU",
            regolith, metal, ice, energy
        ))
        
        -- Log deposit
        minetest.log("action", "[ROVER MOD] Rover deposited resources at hub")
        
        -- Empty rover inventory
        self.inventory.regolith = 0
        self.inventory.metal = 0
        self.inventory.ice = 0
        
        return true
    end,
})