-- ant/entity.lua
local modpath = minetest.get_modpath(minetest.get_current_modname())

local C   = dofile(modpath.."/ant/constants.lua")
local move= dofile(modpath.."/ant/movement.lua")
local dig = dofile(modpath.."/ant/digging.lua")
local res = dofile(modpath.."/ant/resource.lua")

local ant = {
	-- -------- static fields ----------
	initial_properties = C.initial_properties,

	-- -------- dynamic state ----------
	steps_taken   = 0,
	current_direction = nil,
	dig_cooldown  = 0,
	max_regolith  = C.INVENTORY_CAPACITY,
	returning     = false,
	inventory     = {regolith=0, metal=0, ice=0},
	climb_wander     = 0,    -- >0 ⇒ in vertical‑climb mode
	down_stair_mode  = false,
    
    -- ---------replication step properties ---------
    builder         = false,   -- Is this a builder ant?
    builder_target  = nil,     -- Vector pos 50 m away
    nest_radius     = 3,       -- Size of cavity to dig
    building_done   = false,   -- Set once the new nest is finished

    -----------------------------------------------------------------
    -- inside the great big `local ant = { … }` table
    -----------------------------------------------------------------
    -- hauler properties  ---------------------------------------
    hauler          = false,   -- carries a hub from A to B
    carrying_node   = nil,     -- name of the node we removed
    delivery_pos    = nil,     -- where to put it down
    delivery_done   = false,   -- set once placed


}

-----------------------------------------------------------------
-- Blend in the behaviour tables
table.extend(ant, move)
table.extend(ant, dig)
table.extend(ant, res)
-----------------------------------------------------------------

inventory_full = dig.inventory_full

-- on_activate is short and sweet now
function ant.on_activate(self, staticdata)
	minetest.log("action", "[ROVER MOD] Rover unit activated")
	self.object:set_acceleration({x=0, y=-1, z=0}) -- gentle gravity
	self.object:set_properties({physical=true, collide_with_objects=true,
		collisionbox=C.initial_properties.collisionbox})
	self:choose_initial_direction()
end

function ant.deposit_resources(self, hub_pos)
	local meta = minetest.get_meta(hub_pos)

	-- how many regolith blocks we actually drop off?
	local spare   = C.SPARE_BLOCKS
	local dropreg = math.max(0, self.inventory.regolith - spare)

	meta:set_int("regolith", meta:get_int("regolith") + dropreg)
	meta:set_int("metal",    meta:get_int("metal")    + self.inventory.metal)
	meta:set_int("ice",      meta:get_int("ice")      + self.inventory.ice)

	-- keep our spare blocks
	self.inventory.regolith = math.min(self.inventory.regolith, spare)
	self.inventory.metal    = 0
	self.inventory.ice      = 0

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
end

-- dig a quick 7×7×3 cavity and install a hub
local function build_nest(center, radius)
    for dx = -radius, radius do
        for dz = -radius, radius do
            for dy = 0, 2 do              -- height = 3
                local p = {x=center.x+dx, y=center.y-dy, z=center.z+dz}
                minetest.dig_node(p)
            end
        end
    end
    local core = {x=center.x, y=center.y-2, z=center.z}
    minetest.set_node(core, {name="moon:nest_core"})
    local meta = minetest.get_meta(core)
    meta:set_string("infotext", "Fabrication Hub\nResource Storage Empty")
    if moon_energy then moon_energy.add(core, 100) end
    local surf = {x=center.x, y=1, z=center.z}
    minetest.set_node(surf,  {name="moon:solar_array"})
    minetest.get_node_timer(surf):start(10)
    minetest.log("action", "[Builder-ant] New nest carved at "
                 .. minetest.pos_to_string(center))
end

function ant.on_step(self, dtime)
    -------------------------------------------------------------
    --  HAULER MODE   (runs instead of normal rover logic)
    -------------------------------------------------------------
    if self.hauler and not self.delivery_done then
        local pos = self.object:get_pos()

        -- 1.  Travel toward destination ----------------------------------
        if vector.distance(pos, self.delivery_pos) > 1 then
            local dir  = vector.direction(pos, self.delivery_pos); dir.y = 0
            local card = (math.abs(dir.x) > math.abs(dir.z))
                         and {x=(dir.x>0 and 1 or -1), y=0, z=0}
                         or  {x=0, y=0, z=(dir.z>0 and 1 or -1)}
            self.current_direction = card
            self.object:set_yaw(minetest.dir_to_yaw(card))
            self:dig_block()
            self.dig_cooldown = 1.0
            return
        end

        -- 2.  We have arrived – put the hub down -------------------------
        local dest = vector.round(self.delivery_pos)
        if minetest.get_node(dest).name == "air" then
            minetest.set_node(dest, {name = self.carrying_node})
        else
            -- very unlikely, but try the block under our feet
            dest.y = dest.y - 1
            minetest.set_node(dest, {name = self.carrying_node})
        end
        self.delivery_done = true
        self.hauler        = false              -- become a normal rover
        minetest.log("action", "[Hauler-ant] Placed hub at "
                     .. minetest.pos_to_string(dest))
        return
    end

    -- -----------------------------------------------------------
    --  BUILDER MODE   (runs instead of the normal digger logic)
    -- -----------------------------------------------------------
    if self.builder and not self.building_done then
        local pos  = self.object:get_pos()
        -- 1. Still travelling → head toward the target, digging as we go
        if vector.distance(pos, self.builder_target) > 1 then
            local dir = vector.direction(pos, self.builder_target); dir.y = 0
            local card = (math.abs(dir.x) > math.abs(dir.z))
                         and {x=(dir.x>0 and 1 or -1), y=0, z=0}
                         or  {x=0, y=0, z=(dir.z>0 and 1 or -1)}
            self.current_direction = card
            self.object:set_yaw(minetest.dir_to_yaw(card))
            self:dig_block()          -- reuse existing digger
            self.dig_cooldown = 1.0
            return                    -- skip normal rover behaviour
        end
        minetest.log("action", "[Builder-ant] Reached build site, starting nest carving")

        -- 2. Arrived → carve cavity & drop hub
        build_nest(vector.round(self.builder_target), self.nest_radius)
        self.building_done = true
        self.builder       = false    -- now behaves like an ordinary rover
        minetest.log("action", "[Builder-ant] Finished nest. Switching to normal ant behavior")

        return
    end

    ---------------------------------------------------------------
    -- 0.  Choose / update target                                   
    ---------------------------------------------------------------
    local hub_pos = self:find_nearest_hub()
    local priority_resource = nil

    if hub_pos then
        local meta           = minetest.get_meta(hub_pos)
        local regolith_count = meta:get_int("regolith") or 0
        local metal_count    = meta:get_int("metal")    or 0
        local ice_count      = meta:get_int("ice")      or 0

        self.hub_regolith_high = regolith_count >= C.HUB_REGOLITH_THRESHOLD

        if not self.hub_regolith_high then
            if ice_count  <= metal_count and ice_count  <= regolith_count then
                priority_resource = "ice"
            elseif metal_count <= regolith_count then
                priority_resource = "metal"
            else
                priority_resource = "regolith"
            end
        end
    end

    -- when we are in climb‑wander mode just count down
    if self.climb_wander > 0 then
        self.climb_wander = self.climb_wander - 1
    end

    -- no longer doing this
    ---------------------------------------------------------------
    -- 1.  Acquire a fresh target if needed                        
    ---------------------------------------------------------------
    -- if self.target_pos == nil and priority_resource ~= nil then
    --     if priority_resource == "ice" then
    --         self.target_pos = self:find_ice()
    --     elseif priority_resource == "metal" then
    --         self.target_pos = self:find_metal_ore()
    --     end
    -- end

    ---------------------------------------------------------------
    -- 2.  If we are directly beneath target and need to climb     
    ---------------------------------------------------------------
    if self.target_pos then
        local pos = self.object:get_pos()
        local dx  = math.abs(self.target_pos.x - pos.x)
        local dz  = math.abs(self.target_pos.z - pos.z)

        if dx < 0.5 and dz < 0.5 and self.target_pos.y > pos.y + 0.5 then
            -- reached column, start wander‑climb mode
            self.climb_wander = C.CLIMB_WANDER_STEPS
            self:pick_random_horizontal()
        end

        -- reached final height too → clear target
        if math.abs(self.target_pos.y - pos.y) < 0.5 and dx < 0.5 and dz < 0.5 then
            self.target_pos, self.climb_wander = nil, 0
        end
    end

    ---------------------------------------------------------------
    -- 3.  Move toward target (if one) else wander                 
    ---------------------------------------------------------------
    if self.target_pos and self.climb_wander == 0 then
    	-- recompute a proper horizontal heading toward the resource
    	local pos = self.object:get_pos()
    	local dir = vector.direction(pos, self.target_pos); dir.y = 0
    	local card = (math.abs(dir.x) > math.abs(dir.z))
    	             and {x=(dir.x>0 and 1 or -1), y=0, z=0}
    	             or  {x=0, y=0, z=(dir.z>0 and 1 or -1)}
    	self.current_direction = card
    	self.object:set_yaw(minetest.dir_to_yaw(card))


    elseif self.climb_wander > 0 and self.steps_taken % 3 == 0 then
        -- wander a bit while climbing
        self:pick_random_horizontal()
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
    if self.returning and inventory_full(self) then
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
    
    -- -- Check for ice first
    -- local ice_pos = self:find_ice()
    
    -- if ice_pos then
    --     -- Dig toward ice
    --     if self:dig_toward_ice(ice_pos) then
    --         -- Set cooldown to 1 second per digging action
    --         self.dig_cooldown = 1.0
    --     end
    -- else
    -- Normal digging in current direction
    if self:dig_block() then
        -- Set cooldown to 1 second per digging action
        self.dig_cooldown = 1.0
    end
    
    -- Zero velocity while not moving (between digs)
    -- self.object:set_velocity({x=0, y=0, z=0})
end

-----------------------------------------------------------------
-- Keep your full on_step exactly as before.
-- (It already calls functions we imported above.)
-----------------------------------------------------------------

-- Paste on_step here, deleting any code that
-- duplicated definitions now living in modules.
-----------------------------------------------------------------

minetest.register_entity("moon:ant", ant)
