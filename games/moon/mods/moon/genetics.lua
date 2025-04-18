--
-- moon/genetics.lua 
--  • Blueprint genomes for ants
--  • Mutation and evolution systems
--

local S = minetest.get_translator("moon")

-- Default values for ant traits
local DEFAULT_TRAITS = {
    speed = 0.5,           -- Base movement speed
    mining_rate = 1.0,     -- How fast it mines
    search_radius = 8,     -- How far it can detect resources
    carrying_capacity = 1, -- How much it can carry
    radiation_resist = 0.0, -- Resistance to surface radiation (0-1)
    cold_resist = 0.0,     -- Resistance to lunar night cold (0-1)
    energy_efficiency = 1.0 -- Energy usage multiplier (lower is better)
}

-- Function to generate a new trait set with slight mutations
local function generate_mutated_traits(parent_traits)
    local traits = table.copy(parent_traits or DEFAULT_TRAITS)
    
    -- Choose one trait to mutate
    local traits_list = {"speed", "mining_rate", "search_radius", 
                          "carrying_capacity", "radiation_resist", 
                          "cold_resist", "energy_efficiency"}
    
    local trait_to_mutate = traits_list[math.random(#traits_list)]
    
    -- Apply mutation (10-20% change, up or down)
    local mutation_factor = 1.0 + (math.random() * 0.2 - 0.1)
    traits[trait_to_mutate] = traits[trait_to_mutate] * mutation_factor
    
    -- Apply limits to reasonable values
    if trait_to_mutate == "speed" then
        traits.speed = math.max(0.2, math.min(1.5, traits.speed))
    elseif trait_to_mutate == "mining_rate" then
        traits.mining_rate = math.max(0.5, math.min(3.0, traits.mining_rate))
    elseif trait_to_mutate == "search_radius" then
        traits.search_radius = math.max(4, math.min(20, traits.search_radius))
    elseif trait_to_mutate == "carrying_capacity" then
        traits.carrying_capacity = math.max(1, math.min(5, traits.carrying_capacity))
    elseif trait_to_mutate == "radiation_resist" then
        traits.radiation_resist = math.max(0.0, math.min(0.9, traits.radiation_resist))
    elseif trait_to_mutate == "cold_resist" then
        traits.cold_resist = math.max(0.0, math.min(0.9, traits.cold_resist))
    elseif trait_to_mutate == "energy_efficiency" then
        traits.energy_efficiency = math.max(0.5, math.min(1.5, traits.energy_efficiency))
    end
    
    return traits, trait_to_mutate
end

-- Create an advanced blueprint item that contains trait information
minetest.register_craftitem("moon:ant_blueprint", {
    description = S("Ant Blueprint (Base Model)"),
    inventory_image = "moon_ant_blueprint.png",
    stack_max = 10,
    
    on_place = function(itemstack, placer, pointed_thing)
        -- Same functionality as regular cocoon but passes traits
        if pointed_thing.type ~= "node" then
            return itemstack
        end
        
        local pos = pointed_thing.above
        local has_energy = false
        
        -- Get traits from item meta
        local meta = itemstack:get_meta()
        local traits_string = meta:get_string("traits")
        local traits = minetest.deserialize(traits_string) or DEFAULT_TRAITS
        
        -- Check for nearby energy source
        local nests = minetest.find_nodes_in_area(
            {x=pos.x-5, y=pos.y-5, z=pos.z-5},
            {x=pos.x+5, y=pos.y+5, z=pos.z+5},
            {"moon:nest_core"}
        )
        
        for _, nest_pos in ipairs(nests) do
            -- Calculate energy needed based on traits
            local energy_cost = 10 * traits.energy_efficiency
            
            if moon_energy.get(nest_pos) >= energy_cost then
                -- Found a nest with enough energy to activate the blueprint
                moon_energy.take(nest_pos, energy_cost)
                has_energy = true
                break
            end
        end
        
        if has_energy then
            -- Spawn a new ant with these traits
            pos.y = pos.y + 0.5 -- Raise slightly above ground
            local obj = minetest.add_entity(pos, "moon:ant")
            
            -- Apply traits to the new ant
            local ent = obj:get_luaentity()
            ent.traits = table.copy(traits)
            
            -- Apply traits to ant behavior
            if ent.traits.speed then
                -- Will be used in get_speed_factor() method
                ent.base_speed = ent.traits.speed
            end
            
            if ent.traits.search_radius then
                ent.search_radius = ent.traits.search_radius
            end
            
            -- Update visuals based on traits
            obj:set_properties({
                visual_size = {
                    x = 1.0 + traits.carrying_capacity * 0.1, 
                    y = 1.0 + traits.carrying_capacity * 0.1
                }
            })
            
            -- Report on the new ant's traits
            local trait_name = meta:get_string("mutated_trait") or "none"
            minetest.chat_send_player(placer:get_player_name(), 
                "Ant activated from blueprint! Specialized in: " .. trait_name)
            
            -- Consume the blueprint
            itemstack:take_item()
            return itemstack
        else
            minetest.chat_send_player(placer:get_player_name(), 
                "Cannot activate blueprint: No nest with enough energy nearby!")
            return itemstack
        end
    end
})

-- Measure ant performance and create evolved blueprints
local ant_performance = {}

-- Create a unique ID counter for ants
local ant_id_counter = 0

-- Register a function to track ant effectiveness
local function record_ant_efficiency(ant_entity, resource_type, amount)
    -- Create or get a unique ID for this ant
    if not ant_entity.genome_id then
        ant_id_counter = ant_id_counter + 1
        ant_entity.genome_id = "ant_" .. tostring(ant_id_counter)
    end
    
    local id = ant_entity.genome_id
    
    if not ant_performance[id] then
        ant_performance[id] = {
            traits = ant_entity.traits or DEFAULT_TRAITS,
            resources_collected = 0,
            last_active = os.time()
        }
    end
    
    -- Update stats
    ant_performance[id].resources_collected = ant_performance[id].resources_collected + amount
    ant_performance[id].last_active = os.time()
end

-- Add the tracking function to the global API
moon_genetics = {
    record_efficiency = record_ant_efficiency,
    get_default_traits = function() return table.copy(DEFAULT_TRAITS) end
}

-- Automatically generate improved blueprints at dawn
local last_dawn_check = 0

minetest.register_globalstep(function(dtime)
    -- Only check occasionally
    if math.random() > dtime * 0.05 then return end
    
    local tod = minetest.get_timeofday()
    
    -- Dawn time is around 0.23
    if tod > 0.22 and tod < 0.25 and os.time() - last_dawn_check > 300 then
        last_dawn_check = os.time()
        
        -- Find the best performing ant from the past day
        local best_ant_id = nil
        local best_performance = 0
        local current_time = os.time()
        
        for id, data in pairs(ant_performance) do
            -- Only consider active ants from the past day
            if current_time - data.last_active < 86400 then -- 24 hours
                if data.resources_collected > best_performance then
                    best_performance = data.resources_collected
                    best_ant_id = id
                end
            else
                -- Clean up old records
                ant_performance[id] = nil
            end
        end
        
        -- If we found a good performer, generate a blueprint based on it
        if best_ant_id and best_performance > 5 then
            -- Get the traits of the best performer
            local parent_traits = ant_performance[best_ant_id].traits
            
            -- Create slightly mutated traits for next generation
            local new_traits, mutated_trait = generate_mutated_traits(parent_traits)
            
            -- Find a nest to place the blueprint in
            local players = minetest.get_connected_players()
            if #players > 0 then
                local player = players[1]  -- Use first player as reference point
                local player_pos = player:get_pos()
                
                local nests = minetest.find_nodes_in_area(
                    {x=player_pos.x-50, y=player_pos.y-50, z=player_pos.z-50},
                    {x=player_pos.x+50, y=player_pos.y+50, z=player_pos.z+50},
                    {"moon:nest_core"}
                )
                
                if #nests > 0 then
                    -- Create a new blueprint item
                    local blueprint = ItemStack("moon:ant_blueprint")
                    local meta = blueprint:get_meta()
                    
                    -- Store traits in item metadata
                    meta:set_string("traits", minetest.serialize(new_traits))
                    meta:set_string("mutated_trait", mutated_trait)
                    
                    -- Create description showing the specialized trait
                    meta:set_string("description", 
                        S("Ant Blueprint (Enhanced " .. mutated_trait:gsub("_", " "):gsub("^%l", string.upper) .. ")"))
                    
                    -- Add blueprint to the nest's position
                    local pos = nests[1]
                    pos.y = pos.y + 1  -- Place above nest
                    
                    -- Drop the item into the world
                    minetest.add_item(pos, blueprint)
                    
                    -- Notify players
                    for _, player in ipairs(players) do
                        minetest.chat_send_player(player:get_player_name(),
                            "Dawn has arrived! A new evolved blueprint has appeared at a nest core!")
                    end
                end
            end
        end
    end
end)

-- Create a basic blueprint from the fabricator occasionally
local original_fabricator_receive_fields = minetest.registered_nodes["moon:fabricator"].on_receive_fields

minetest.override_item("moon:fabricator", {
    on_receive_fields = function(pos, formname, fields, sender)
        -- Let the original handler run first
        local result = original_fabricator_receive_fields(pos, formname, fields, sender)
        
        -- If we're creating an ant, occasionally make a blueprint instead
        if fields.create and math.random() < 0.2 then  -- 20% chance
            -- Find a nest to get resources from
            local nests = minetest.find_nodes_in_area(
                {x=pos.x-5, y=pos.y-5, z=pos.z-5},
                {x=pos.x+5, y=pos.y+5, z=pos.z+5},
                {"moon:nest_core"}
            )
            
            local nest_pos = nil
            for _, np in ipairs(nests) do
                local nest_meta = minetest.get_meta(np)
                local regolith = nest_meta:get_int("regolith")
                local metal = nest_meta:get_int("metal")
                local energy = moon_energy.get(np)
                
                -- Needs more resources than regular ant
                if regolith >= 4 and metal >= 2 and energy >= 10 then
                    nest_pos = np
                    break
                end
            end
            
            if nest_pos then
                -- Consume additional resources
                local nest_meta = minetest.get_meta(nest_pos)
                nest_meta:set_int("regolith", nest_meta:get_int("regolith") - 2)  -- Extra -2 (total 4)
                nest_meta:set_int("metal", nest_meta:get_int("metal") - 1)        -- Extra -1 (total 2)
                moon_energy.take(nest_pos, 5)  -- Extra 5 (total 10)
                
                -- Create a new blueprint
                local traits, mutated_trait = generate_mutated_traits(DEFAULT_TRAITS)
                
                local blueprint = ItemStack("moon:ant_blueprint")
                local meta = blueprint:get_meta()
                
                -- Store traits in item metadata
                meta:set_string("traits", minetest.serialize(traits))
                meta:set_string("mutated_trait", mutated_trait)
                
                -- Create description showing the specialized trait
                meta:set_string("description", 
                    S("Ant Blueprint (Basic " .. mutated_trait:gsub("_", " "):gsub("^%l", string.upper) .. ")"))
                
                -- Give to player
                local player_name = sender:get_player_name()
                local inv = minetest.get_player_by_name(player_name):get_inventory()
                
                if inv:room_for_item("main", blueprint) then
                    inv:add_item("main", blueprint)
                    minetest.chat_send_player(player_name, 
                        "The fabricator created a blueprint instead of a basic ant!")
                else
                    -- Drop it if inventory is full
                    minetest.add_item(pos, blueprint)
                end
            end
        end
        
        return result
    end
})

-- Add a command to create a blueprint for testing
minetest.register_chatcommand("makeblueprint", {
    description = "Create a random ant blueprint",
    func = function(name, param)
        local player = minetest.get_player_by_name(name)
        if not player then return false, "Player not found" end
        
        local traits, mutated_trait = generate_mutated_traits(DEFAULT_TRAITS)
        
        local blueprint = ItemStack("moon:ant_blueprint")
        local meta = blueprint:get_meta()
        
        -- Store traits in item metadata
        meta:set_string("traits", minetest.serialize(traits))
        meta:set_string("mutated_trait", mutated_trait)
        
        -- Create description showing the specialized trait
        meta:set_string("description", 
            S("Ant Blueprint (Test " .. mutated_trait:gsub("_", " "):gsub("^%l", string.upper) .. ")"))
        
        -- Give to player
        local inv = player:get_inventory()
        
        if inv:room_for_item("main", blueprint) then
            inv:add_item("main", blueprint)
            return true, "Created a blueprint with enhanced " .. mutated_trait
        else
            -- Drop it if inventory is full
            minetest.add_item(player:get_pos(), blueprint)
            return true, "Inventory full, dropped blueprint at your position"
        end
    end,
})