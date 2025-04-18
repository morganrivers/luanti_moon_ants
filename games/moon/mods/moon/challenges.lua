--
-- moon/challenges.lua
--  • Environmental challenges and survival mechanics for ants
--

local RADIATION_DAMAGE = 1   -- HP/s damage from cosmic radiation on surface
local FREEZE_THRESHOLD = 10  -- Energy threshold below which ants freeze at night
local NIGHT_DRAIN_MULT = 2   -- Battery drain multiplier at night

-------------------------------------------------
-- Register periodic environmental challenge handler
-------------------------------------------------
minetest.register_globalstep(function(dtime)
    -- Only run every 2 seconds to reduce server load
    if math.random() > dtime * 0.5 then return end
    
    local tod = minetest.get_timeofday() -- 0..1
    local is_night = (tod < 0.23 or tod > 0.77)
    
    -- -- Get all active ant entities
    -- for _, player in ipairs(minetest.get_connected_players()) do
    --     -- Only check near players to improve performance
    --     local player_pos = player:get_pos()
    --     local objects = minetest.get_objects_inside_radius(player_pos, 50)
        
    --     for _, obj in ipairs(objects) do
    --         local ent = obj:get_luaentity()
    --         if ent and ent.name == "moon:ant" then
    --             -- Challenge 1: Vacuum and cosmic radiation (surface light level)
    --             local pos = obj:get_pos()
    --             local light_level = minetest.get_node_light(pos, 0.5) or 0
                
    --             -- Apply radiation damage when in bright light (surface exposure)
    --             if light_level > 12 then
    --                 -- Check for radiation resistance from traits
    --                 local radiation_resist = 0
    --                 if ent.traits and ent.traits.radiation_resist then
    --                     radiation_resist = ent.traits.radiation_resist
    --                 end
                    
    --                 -- Calculate damage with resistance
    --                 local damage = RADIATION_DAMAGE * (1.0 - radiation_resist)
                    
    --                 if damage > 0 then
    --                     local hp = obj:get_hp()
    --                     obj:set_hp(hp - damage)
                        
    --                     -- Visual effect for radiation damage (less particles with resistance)
    --                     local particle_count = math.ceil(5 * (1.0 - radiation_resist))
    --                     if particle_count > 0 then
    --                         minetest.add_particlespawner({
    --                             amount = particle_count,
    --                             time = 0.5,
    --                             minpos = {x=pos.x-0.2, y=pos.y, z=pos.z-0.2},
    --                             maxpos = {x=pos.x+0.2, y=pos.y+0.4, z=pos.z+0.2},
    --                             minvel = {x=-0.5, y=0.5, z=-0.5},
    --                             maxvel = {x=0.5, y=1, z=0.5},
    --                             minacc = {x=0, y=0, z=0},
    --                             maxacc = {x=0, y=0, z=0},
    --                             minexptime = 0.5,
    --                             maxexptime = 1,
    --                             minsize = 1,
    --                             maxsize = 2,
    --                             collisiondetection = false,
    --                             texture = "moon_radiation_particle.png",
    --                         })
    --                     end
    --                 end
    --             end
                
    --             -- Challenge 2: Deep cold at lunar night
    --             if is_night then
    --                 -- Find nearest nest core to check energy
    --                 local nests = minetest.find_nodes_in_area(
    --                     {x=pos.x-20, y=pos.y-20, z=pos.z-20},
    --                     {x=pos.x+20, y=pos.y+20, z=pos.z+20},
    --                     {"moon:nest_core"}
    --                 )
                    
    --                 local has_energy = false
    --                 for _, nest_pos in ipairs(nests) do
    --                     -- Check if nest has enough energy to protect this ant
    --                     if moon_energy.get(nest_pos) > FREEZE_THRESHOLD then
    --                         -- Calculate energy usage based on efficiency
    --                         local energy_factor = 1.0
    --                         if ent.traits and ent.traits.energy_efficiency then
    --                             energy_factor = ent.traits.energy_efficiency
    --                         end
                            
    --                         -- Drain energy faster at night for temperature regulation
    --                         moon_energy.take(nest_pos, dtime * NIGHT_DRAIN_MULT * energy_factor)
    --                         has_energy = true
    --                         break
    --                     end
    --                 end
                    
    --                 -- If no energy available, ant freezes (unless cold resistant)
    --                 if not has_energy then
    --                     -- Check for cold resistance from traits
    --                     local cold_resist = 0
    --                     if ent.traits and ent.traits.cold_resist then
    --                         cold_resist = ent.traits.cold_resist
    --                     end
                        
    --                     -- Chance to avoid freezing entirely based on cold_resist
    --                     if math.random() < cold_resist then
    --                         -- Cold resistant ant survives without energy
    --                     else
    --                         -- Make ant slow way down first as warning
    --                         if ent.cold_level then
    --                             -- Cold resistance slows the freezing process
    --                             local cold_factor = 1.0 - cold_resist
    --                             ent.cold_level = ent.cold_level + (dtime * cold_factor)
                                
    --                             -- Progressively slow down movement
    --                             local speed_factor = math.max(0.1, 1.0 - (ent.cold_level / 5.0))
    --                             local vel = obj:get_velocity()
    --                             obj:set_velocity({
    --                                 x = vel.x * speed_factor,
    --                                 y = vel.y,
    --                                 z = vel.z * speed_factor
    --                             })
                                
    --                             -- After sustained cold exposure, freeze completely
    --                             if ent.cold_level > 10.0 then
    --                                 obj:set_hp(0) -- Ant freezes to death
                                    
    --                                 -- Visual effect for freezing
    --                                 minetest.add_particlespawner({
    --                                     amount = 10,
    --                                     time = 1,
    --                                     minpos = {x=pos.x-0.3, y=pos.y, z=pos.z-0.3},
    --                                     maxpos = {x=pos.x+0.3, y=pos.y+0.5, z=pos.z+0.3},
    --                                     minvel = {x=-0.1, y=0.1, z=-0.1},
    --                                     maxvel = {x=0.1, y=0.2, z=0.1},
    --                                     minacc = {x=0, y=0, z=0},
    --                                     maxacc = {x=0, y=0, z=0},
    --                                     minexptime = 1,
    --                                     maxexptime = 2,
    --                                     minsize = 1,
    --                                     maxsize = 2,
    --                                     collisiondetection = false,
    --                                     texture = "moon_ice_particle.png",
    --                                 })
    --                             end
    --                         else
    --                             ent.cold_level = 0.1 -- Initialize cold counter
    --                         end
    --                     end
    --                 else
    --                     -- Reset cold counter when near an energized nest
    --                     if ent.cold_level then
    --                         ent.cold_level = 0
    --                     end
    --                 end
    --             else
    --                 -- Reset cold counter during the day
    --                 if ent.cold_level then
    --                     ent.cold_level = 0
    --                 end
    --             end
    --         end
    --     end
    -- end
end)

-------------------------------------------------
-- Hardened regolith - allows ants to dig tunnels for protection
-------------------------------------------------
minetest.register_node("moon:regolith_hardened", {
    description = "Hardened Moon Regolith",
    tiles = {"moon_regolith_hardened.png"},
    groups = {cracky = 2, regolith = 1},
    sounds = default.node_sound_stone_defaults(),
})

-- Register crafting recipe (ants can build tunnels from regolith)
minetest.register_craft({
    output = "moon:regolith_hardened",
    recipe = {
        {"moon:regolith", "moon:regolith"},
        {"moon:regolith", "moon:regolith"},
    }
})

-------------------------------------------------
-- Rare resource: Phosphorus nodule (needed for circuit doping)
-------------------------------------------------
minetest.register_node("moon:phosphorus_nodule", {
    description = "Phosphorus-bearing Nodule",
    tiles = {"moon_phosphorus_nodule.png"},
    groups = {cracky = 3, phosphorus = 1},
    drop = "moon:phosphorus_piece",
    light_source = 2, -- Faint glow
})

minetest.register_craftitem("moon:phosphorus_piece", {
    description = "Phosphorus Sample",
    inventory_image = "moon_phosphorus_piece.png",
})

-- Add phosphorus as a very rare ore
minetest.register_ore({
    ore_type       = "scatter",
    ore            = "moon:phosphorus_nodule",
    wherein        = "moon:regolith",
    clust_scarcity = 100*100*100,
    clust_num_ores = 1,
    clust_size     = 1,
    y_min          = -64,
    y_max          = -20,
})

-- Update fabricator recipe to occasionally need ice
-- (this modifies the existing fabricator logic to check for ice when creating more advanced ants)
local original_fabricator_fields = minetest.registered_nodes["moon:fabricator"].on_receive_fields

minetest.override_item("moon:fabricator", {
    on_receive_fields = function(pos, formname, fields, sender)
        -- Check if this is a "create" button press
        if fields.create then
            -- Get nest resource information
            local nests = minetest.find_nodes_in_area(
                {x=pos.x-5, y=pos.y-5, z=pos.z-5},
                {x=pos.x+5, y=pos.y+5, z=pos.z+5},
                {"moon:nest_core"}
            )
            
            -- Count total ants to determine if ice is needed
            local ants_count = 0
            for _, player in ipairs(minetest.get_connected_players()) do
                local player_pos = player:get_pos()
                local objects = minetest.get_objects_inside_radius(player_pos, 100)
                
                for _, obj in ipairs(objects) do
                    local ent = obj:get_luaentity()
                    if ent and ent.name == "moon:ant" then
                        ants_count = ants_count + 1
                    end
                end
            end
            
            -- Every 5th ant needs ice as coolant for electrolytic plating
            local needs_ice = (ants_count % 5 == 0 and ants_count > 0)
            
            if needs_ice then
                local has_ice = false
                local nest_pos = nil
                
                for _, np in ipairs(nests) do
                    local nest_meta = minetest.get_meta(np)
                    if nest_meta:get_int("ice") > 0 then
                        has_ice = true
                        nest_pos = np
                        break
                    end
                end
                
                if not has_ice then
                    minetest.chat_send_player(sender:get_player_name(), 
                        "Cannot create ant: Need ice for electrolytic plating coolant!")
                    return
                else
                    -- Consume ice from the nest
                    local nest_meta = minetest.get_meta(nest_pos)
                    nest_meta:set_int("ice", nest_meta:get_int("ice") - 1)
                    
                    -- Update infotext
                    local regolith = nest_meta:get_int("regolith")
                    local metal = nest_meta:get_int("metal")
                    local ice = nest_meta:get_int("ice")
                    local energy = moon_energy.get(nest_pos)
                    nest_meta:set_string("infotext", string.format(
                        "Nest Core\nRegolith: %d\nMetal: %d\nIce: %d\nEnergy: %d EU",
                        regolith, metal, ice, energy
                    ))
                end
            end
        end
        
        -- Call the original handler
        return original_fabricator_fields(pos, formname, fields, sender)
    end
})