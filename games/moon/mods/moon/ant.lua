-- Improved Ant Entity for Moon Mod

minetest.log("action", "[ANTS MOD] Registering ant entity")

-- Register the ant entity
minetest.register_entity("moon:ant", {
    initial_properties = {
        physical = true,
        collide_with_objects = true,
        collisionbox = {-0.2, -0.01, -0.2, 0.2, 0.2, 0.2},
        visual = "sprite",  -- Using sprite is more reliable than mesh
        textures = {"ant.png"}, 
        visual_size = {x = 1.0, y = 1.0},  -- Bigger to be more visible
        nametag = "Moon Ant",
        nametag_color = "#FF0000",
        is_visible = true,
        makes_footstep_sound = true,
    },
    
    -- Entity variables
    timer = 0,
    move_timer = 0,
    
    on_activate = function(self, staticdata)
        minetest.log("action", "[ANTS MOD] Ant activated at " .. 
            minetest.pos_to_string(self.object:get_pos()))
        self.object:set_acceleration({x=0, y=-10, z=0}) -- Gravity
        
        -- Initial movement
        local yaw = math.random() * math.pi * 2
        self.object:set_yaw(yaw)
        self.object:set_velocity({
            x = math.cos(yaw) * 0.5,
            y = 0,
            z = math.sin(yaw) * 0.5,
        })
    end,

    on_step = function(self, dtime)
        self.timer = (self.timer or 0) + dtime
        self.move_timer = (self.move_timer or 0) + dtime
        
        -- Change direction occasionally
        if self.move_timer > 2 then
            self.move_timer = 0
            local yaw = math.random() * math.pi * 2
            self.object:set_yaw(yaw)
            
            -- Set velocity more explicitly
            self.object:set_velocity({
                x = math.cos(yaw) * 0.5,
                y = 0,  -- Keep at 0 to stay on ground
                z = math.sin(yaw) * 0.5,
            })
            
            -- Add a small debug message
            if self.timer > 10 then
                self.timer = 0
                minetest.log("action", "[ANTS MOD] Ant at " .. 
                    minetest.pos_to_string(self.object:get_pos()))
            end
        end
    end,
    
    -- Add a punch handler for debugging
    on_punch = function(self, puncher, time_from_last_punch, tool_capabilities, dir)
        minetest.log("action", "[ANTS MOD] Ant punched!")
        minetest.chat_send_player(puncher:get_player_name(), "You found a moon ant!")
        return true
    end,
})

-- Add a spawn egg for testing
minetest.register_craftitem("moon:ant_spawn_egg", {
    description = "Moon Ant Spawn Egg",
    inventory_image = "default_sand.png^[colorize:#FF0000:50",
    on_place = function(itemstack, placer, pointed_thing)
        if pointed_thing.type ~= "node" then
            return itemstack
        end
        
        local pos = pointed_thing.above
        pos.y = pos.y + 0.5 -- Raise slightly above ground
        
        minetest.log("action", "[ANTS MOD] Spawning ant at " .. 
            minetest.pos_to_string(pos))
        minetest.add_entity(pos, "moon:ant")
        minetest.chat_send_player(placer:get_player_name(), "Ant spawned at " .. 
            minetest.pos_to_string(pos))
        
        if not minetest.is_creative_enabled(placer:get_player_name()) then
            itemstack:take_item()
        end
        
        return itemstack
    end,
})

-- Spawn ants on command
minetest.register_chatcommand("spawnant", {
    description = "Spawn a moon ant at your position",
    func = function(name, param)
        local player = minetest.get_player_by_name(name)
        if not player then return false, "Player not found" end
        
        local pos = player:get_pos()
        pos.y = pos.y + 1
        
        minetest.add_entity(pos, "moon:ant")
        return true, "Ant spawned at " .. minetest.pos_to_string(pos)
    end,
})

-- Automatic ant spawning near regolith
minetest.register_abm({
    label = "Spawn Moon Ants",
    nodenames = {"moon:regolith"},
    interval = 10, -- Check every 10 seconds (faster than before)
    chance = 20, -- 5% chance per check (higher than before)
    action = function(pos, node)
        -- Check if there are already ants nearby
        local objs = minetest.get_objects_inside_radius(pos, 10)
        local ant_count = 0
        
        for _, obj in ipairs(objs) do
            local ent = obj:get_luaentity()
            if ent and ent.name == "moon:ant" then
                ant_count = ant_count + 1
            end
        end
        
        -- Don't spawn too many ants in one area
        if ant_count < 5 then
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

-- Spawn ants when a player joins the game
minetest.register_on_joinplayer(function(player)
    minetest.log("action", "[ANTS MOD] Player joined, spawning initial ants")
    
    -- Delay slightly to make sure the player is fully loaded
    minetest.after(2, function()
        local player_pos = player:get_pos()
        
        -- Spawn 5 ants around the player
        for i = 1, 5 do
            local spawn_pos = {
                x = player_pos.x + math.random(-10, 10),
                y = player_pos.y + 1,
                z = player_pos.z + math.random(-10, 10)
            }
            
            -- Make sure we're spawning in air
            if minetest.get_node(spawn_pos).name == "air" then
                minetest.log("action", "[ANTS MOD] Spawning initial ant at " .. 
                    minetest.pos_to_string(spawn_pos))
                minetest.add_entity(spawn_pos, "moon:ant")
            else
                -- If we can't spawn at the random location, spawn closer to player
                spawn_pos = {
                    x = player_pos.x + math.random(-3, 3),
                    y = player_pos.y + 1,
                    z = player_pos.z + math.random(-3, 3)
                }
                minetest.log("action", "[ANTS MOD] Spawning initial ant (fallback) at " .. 
                    minetest.pos_to_string(spawn_pos))
                minetest.add_entity(spawn_pos, "moon:ant")
            end
        end
        
        -- Let the player know about the ants
        minetest.chat_send_player(player:get_player_name(), 
            "Welcome to the moon! Look around for the moon ants!")
    end)
end)

-- Debug tool - to count active entities
minetest.register_chatcommand("countants", {
    description = "Count ants around you",
    func = function(name, param)
        local player = minetest.get_player_by_name(name)
        if not player then return false, "Player not found" end
        
        local pos = player:get_pos()
        local radius = tonumber(param) or 20
        
        local objs = minetest.get_objects_inside_radius(pos, radius)
        local ant_count = 0
        
        for _, obj in ipairs(objs) do
            local ent = obj:get_luaentity()
            if ent and ent.name == "moon:ant" then
                ant_count = ant_count + 1
            end
        end
        
        return true, "Found " .. ant_count .. " ants within " .. radius .. " blocks"
    end,
})

minetest.log("action", "[ANTS MOD] Ant mod fully loaded")