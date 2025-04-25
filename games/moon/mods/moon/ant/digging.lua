

-- moon/ant/digging.lua
--  All terrain‑interaction helpers for the rover entity
-----------------------------------------------------------

local C = dofile(minetest.get_modpath(minetest.get_current_modname())
                 .."/ant/constants.lua")

local D = {}

local function inventory_full(self)
    local slots = self.inventory.regolith +
                  self.inventory.metal    +
                  self.inventory.ice
    return slots >= self.max_regolith or
           self.inventory.ice   > 0    or
           self.inventory.metal > 0
end

------------------------------------------------------------------
--  FINDERS
------------------------------------------------------------------
-- function D.find_ice(self, radius)
-- 	radius = radius or C.RESOURCE_SCAN_RADIUS
-- 	local pos = self.object:get_pos();  if not pos then return nil end

-- 	local best, bestd = nil, radius+1
-- 	for x=-radius, radius do
-- 		for y=-radius, radius do
-- 			for z=-radius, radius do
-- 				local p = vector.add(pos,{x=x,y=y,z=z})
-- 				local n = minetest.get_node_or_nil(p)
-- 				if n and n.name == "moon:ice_rock" then
-- 					local d = vector.distance(pos,p)
-- 					if d < bestd then best,bestd = p,d end
-- 				end
-- 			end
-- 		end
-- 	end
-- 	return best
-- end

-- function D.find_metal_ore(self, radius)
-- 	radius = radius or C.RESOURCE_SCAN_RADIUS
-- 	local pos = self.object:get_pos();  if not pos then return nil end

-- 	local best, bestd = nil, radius+1
-- 	for x=-radius, radius do
-- 		for y=-radius, radius do
-- 			for z=-radius, radius do
-- 				local p = vector.add(pos,{x=x,y=y,z=z})
-- 				local n = minetest.get_node_or_nil(p)
-- 				if n and n.name == "moon:metal_ore" then
-- 					local d = vector.distance(pos,p)
-- 					if d < bestd then best,bestd = p,d end
-- 				end
-- 			end
-- 		end
-- 	end
-- 	return best
-- end

------------------------------------------------------------------
--  DIRECTIONAL DIG HELPERS  (identical logic, different targets)
------------------------------------------------------------------
local function dig_toward(self, goal_pos, reward_ice, reward_metal)
	local pos = self.object:get_pos(); if not pos or not goal_pos then return false end
	pos = {x=math.floor(pos.x+0.5), y=math.floor(pos.y+0.5), z=math.floor(pos.z+0.5)}

	-- choose biggest component → cardinal step
	local dir      = vector.direction(pos, goal_pos); dir.y = 0
	local step_dir = (math.abs(dir.x) > math.abs(dir.z))
	                 and {x=(dir.x>0 and 1 or -1),y=0,z=0}
	                 or  {x=0,y=0,z=(dir.z>0 and 1 or -1)}

	self.current_direction = step_dir
	self.object:set_yaw(minetest.dir_to_yaw(step_dir))

	local front = vector.add(pos, step_dir)
	local node  = minetest.get_node(front)
	if node.name ~= "air" then minetest.dig_node(front) end
	self.object:set_pos(front)

	-- book‑keeping
	if reward_ice  and node.name == "moon:ice_rock"   then self.inventory.ice   = self.inventory.ice+1  end
	if reward_metal and node.name == "moon:metal_ore" then self.inventory.metal = self.inventory.metal+1 end
	return true
end

function D.dig_toward_ice(self, ice_pos)
	self.target_pos = ice_pos
	return dig_toward(self, ice_pos,  true, false)
end
function D.dig_toward_metal(self, ore_pos)
	self.target_pos = ore_pos
	return dig_toward(self, ore_pos,  false,true)
end
local function must_climb(self, pos)
   if not self.target_pos then return false end
   return self.target_pos.y > pos.y + 0.1      -- 0.1 ⇒ tolerance
end
local function vertical_intent(self, pos)
    if not self.target_pos then return nil end
    local dy = self.target_pos.y - pos.y
    if math.abs(dy) < 0.5 then return nil end          -- same height
    return (dy > 0) and "up" or "down"
end

-- dig a resource directly beneath the rover (or the node it is inside)
local function collect_underfoot(self, pos)
    local here  = {x = math.floor(pos.x+0.5),
                   y = math.floor(pos.y+0.5),
                   z = math.floor(pos.z+0.5)}
    local below = {x = here.x, y = here.y-1, z = here.z}

    for _, p in ipairs({here, below}) do
        local n = minetest.get_node(p)
        if n.name == "moon:ice_rock" then
            minetest.dig_node(p)
            self.inventory.ice = self.inventory.ice + 1
            self.returning     = true        -- go home with the prize
            return true
        elseif n.name == "moon:metal_ore" then
            minetest.dig_node(p)
            self.inventory.metal = self.inventory.metal + 1
            self.returning       = true
            return true
        end
    end
    return false
end

local function exposed_to_sky(pos, max_air_height)
    for dy = 1, max_air_height do
        local p = {x = pos.x, y = pos.y + dy, z = pos.z}
        local node = minetest.get_node_or_nil(p)
        if not node then
            minetest.log("warning", "[ROVER MOD] Node above "
                .. minetest.pos_to_string(p) .. " is nil — assuming sky exposure")
            return true  -- safer to treat nil as exposed
        end
        if node.name == "ignore" then
            minetest.log("warning", "[ROVER MOD] Node above "
                .. minetest.pos_to_string(p) .. " is 'ignore' — assuming sky exposure")
            return true
        end
        if node.name ~= "air" then
            return false  -- blocked!
        end
    end
    return true
end

function D.dig_block(self)
    -- Check for exposure to surface: 2 blocks of air above
    local pos = self.object:get_pos()
    if not pos then return false end

    local rounded_pos = {
        x = math.floor(pos.x + 0.5),
        y = math.floor(pos.y + 0.5),
        z = math.floor(pos.z + 0.5)
    }


	if not pos then return false end
	if collect_underfoot(self, pos) then return true end

    -- vertical intention for this step
    local vmode = vertical_intent(self, pos)   -- "up", "down", or nil

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
    local node = minetest.get_node(front_pos)   -- ← you accidentally deleted this

    local front_2 = {
        x = rounded_pos.x + self.current_direction.x * 2,
        y = rounded_pos.y,
        z = rounded_pos.z + self.current_direction.z * 2
    }

    if exposed_to_sky(front_pos, 100) or exposed_to_sky(front_2, 100) then
        minetest.log("action", "[ROVER MOD] Surface exposure detected 1–2 blocks ahead at " ..
            minetest.pos_to_string(front_pos) .. " or " .. minetest.pos_to_string(front_2) ..
            " — digging down to stay hidden")
        return self:dig_down_step()
    end


    if node and node.name == "air" then
        self.object:set_pos(front_pos)
        self.steps_taken = self.steps_taken + 1

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
    
    -- ① the whole “Path is blocked – first try to climb up …” section
    if must_climb(self, pos) then

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
	            	if (not self.hub_regolith_high) and (self.inventory.regolith < self.max_regolith) then
	            	    self.inventory.regolith = self.inventory.regolith + 1
	            	end
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
	                    if (not self.hub_regolith_high) and (self.inventory.regolith < self.max_regolith) then
	                        self.inventory.regolith = self.inventory.regolith + 1
	                    end
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
	            if inventory_full(self) then
	            	self.returning = true 
	            elseif self.steps_taken >= 10 and not self.returning then
	                self:turn_90_degrees()
	            end
	            
	            return true
	        end
	    end
	end

    local pos = self.object:get_pos()
    if not pos then return false end

    local rounded_pos = {
        x = math.floor(pos.x + 0.5),
        y = math.floor(pos.y + 0.5),
        z = math.floor(pos.z + 0.5)
    }
    -- Check both 1 and 2 steps ahead for exposure to sky
    local front_1 = {
        x = rounded_pos.x + self.current_direction.x,
        y = rounded_pos.y,
        z = rounded_pos.z + self.current_direction.z
    }
    local front_2 = {
        x = rounded_pos.x + self.current_direction.x * 2,
        y = rounded_pos.y,
        z = rounded_pos.z + self.current_direction.z * 2
    }

    if exposed_to_sky(front_1, 100) or exposed_to_sky(front_2, 100) then
        minetest.log("action", "[ROVER MOD] Surface exposure detected 1–2 blocks ahead at " ..
            minetest.pos_to_string(front_1) .. " or " .. minetest.pos_to_string(front_2) ..
            " — digging down to stay hidden")
        return self:dig_down_step()
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
                if (not self.hub_regolith_high) and (self.inventory.regolith < self.max_regolith) then
                    self.inventory.regolith = self.inventory.regolith + 1
                end
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
            if inventory_full(self) then
            	self.returning = true
            elseif self.steps_taken >= 10 and not self.returning then
                self:turn_90_degrees()
            end
            
            return true
        end
    end
    
    -- If digging failed and we have blocks, try to place a block to create stairs
    if must_climb(self, pos) and self.inventory.regolith > 0 and not self.returning then
        return self:place_block_for_climbing()
    end

    -- If we need to go DOWN toward the goal, dig a staircase
    if vmode == "down" then
        return self:dig_down_step()
    end

    -- If all else fails, try turning
    self:turn_90_degrees()
    return false
end


-- Place a block to create a stairway for climbing
function D.place_block_for_climbing(self)
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
                        if (not self.hub_regolith_high) and (self.inventory.regolith < self.max_regolith) then
                            self.inventory.regolith = self.inventory.regolith + 1
                        end

                        
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
end
function D.dig_down_step(self)
    local pos = self.object:get_pos()
    if not pos then return false end

    local rounded_pos = {
        x = math.floor(pos.x + 0.5),
        y = math.floor(pos.y + 0.5),
        z = math.floor(pos.z + 0.5)
    }

   if rounded_pos.y <= -200 then
       minetest.log("warning", "[ROVER MOD] Too deep at y=" .. rounded_pos.y .. ", refusing to dig further down")
       return false
   end
   local pos = self.object:get_pos(); if not pos then return false end
   if collect_underfoot(self, pos) then return true end

   pos = {x = math.floor(pos.x+0.5), y = math.floor(pos.y+0.5), z = math.floor(pos.z+0.5)}

   local below = {x=pos.x, y=pos.y-1, z=pos.z}
   local node  = minetest.get_node(below)

   if node.name ~= "air" then
       -- dig the tread block
       minetest.dig_node(below)
   end

   -- step down
   self.object:set_pos(below)
   self.steps_taken = self.steps_taken + 1
   return true
end

D.inventory_full = inventory_full   -- make it accessible to entity.lua

return D
