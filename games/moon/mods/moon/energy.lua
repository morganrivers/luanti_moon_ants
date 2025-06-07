--
-- moon/energy.lua
--  • Super‑lightweight EU cache for solar arrays, batteries & fabricators
--

local modname  = "moon"
local EU_CAP   = 2500   -- hard cap per node (arbitrary, tweak later)

-------------------------------------------------
-- Helper: read / write meta energy field
-------------------------------------------------
local function get_meta(pos)   return minetest.get_meta(pos) end
local function get_eu(pos)
    return tonumber(get_meta(pos):get_int("eu") or 0)
end
local function set_eu(pos, eu)
    get_meta(pos):set_int("eu", math.min(eu, EU_CAP))
end

-------------------------------------------------
-- Public API -------------------------------------------------
moon_energy = {}

function moon_energy.add(pos, amount)
    set_eu(pos, get_eu(pos) + amount)
end

function moon_energy.take(pos, amount)
    local have = get_eu(pos)
    if have < amount then return false end
    set_eu(pos, have - amount)
    return true
end

function moon_energy.get(pos) return get_eu(pos) end

-------------------------------------------------
-- Day/night cycle settings for lunar day
-------------------------------------------------
-- Set day/night cycle to match lunar day length (1 real hour = 1 lunar day)
minetest.settings:set("time_speed", 24)

-------------------------------------------------
-- Solar array node (surface only)
-------------------------------------------------
minetest.register_node("moon:solar_array", {
    description  = "Solar Array",
    tiles        = {"moon_solar_top.png","moon_solar_bottom.png","moon_solar_side.png"},
    groups       = {cracky=2, solar=1},
    light_source = 3,
    on_construct = function(pos)
        set_eu(pos, 0)
        -- update every 10 s
        minetest.get_node_timer(pos):start(10)
    end,
    on_timer = function(pos, elapsed)
        local tod = minetest.get_timeofday() -- 0..1
        local daylight = (tod > 0.23 and tod < 0.77)  -- simple 12 h day
        
        -- Get the meta for infotext updates
        local meta = minetest.get_meta(pos)
        
        if daylight then
            moon_energy.add(pos, 50) -- harvest 50 EU
            meta:set_string("infotext", "Solar Array\nActive - Generating Power\nStored: " .. moon_energy.get(pos) .. " EU")
        else
            -- Not generating during night
            meta:set_string("infotext", "Solar Array\nInactive - Night\nStored: " .. moon_energy.get(pos) .. " EU")
        end
        return true
    end,
    
    on_rightclick = function(pos, node, clicker, itemstack)
        local tod = minetest.get_timeofday()
        local daylight = (tod > 0.23 and tod < 0.77)
        local status = daylight and "Active - Generating Power" or "Inactive - Night"
        
        minetest.chat_send_player(clicker:get_player_name(),
            "Solar Array\nStatus: " .. status .. "\nStored energy: " .. moon_energy.get(pos) .. " EU")
    end,
})

-------------------------------------------------
-- Basic battery (stores energy, portable later)
-------------------------------------------------
minetest.register_node("moon:battery_box", {
    description = "Simple Battery Box",
    tiles       = {"moon_battery.png"},
    groups      = {cracky=2, battery=1},
    on_construct = function(pos)
        set_eu(pos, 0)
        local meta = minetest.get_meta(pos)
        meta:set_string("infotext", "Battery Box\nStored: 0 EU")
    end,
    on_rightclick = function(pos, node, clicker, itemstack)
        local energy = moon_energy.get(pos)
        local meta = minetest.get_meta(pos)
        meta:set_string("infotext", "Battery Box\nStored: " .. energy .. " EU")
        
        minetest.chat_send_player(clicker:get_player_name(),
             "Battery Box\nStored energy: " .. energy .. " EU")
    end,
})

-------------------------------------------------
-- Component Kit (parts for assembling a new machine)
-------------------------------------------------
minetest.register_craftitem("moon:component_kit", {
    description = "Rover Component Kit (Unassembled)",
    inventory_image = "moon_component_kit.png",
    stack_max = 16,
    
    on_place = function(itemstack, placer, pointed_thing)
        if pointed_thing.type ~= "node" then
            return itemstack
        end
        
        local pos = pointed_thing.above
        -- Check if there's enough energy in a nearby fabrication hub
        local has_energy = false
        local hubs = minetest.find_nodes_in_area(
            {x=pos.x-5, y=pos.y-5, z=pos.z-5},
            {x=pos.x+5, y=pos.y+5, z=pos.z+5},
            {"moon:nest_core"}
        )
        
        for _, hub_pos in ipairs(hubs) do
            if moon_energy.get(hub_pos) >= 10 then
                -- Found a hub with enough energy for final assembly
                moon_energy.take(hub_pos, 10)
                has_energy = true
                break
            end
        end
        
        if has_energy then
            -- Spawn a new rover unit
            pos.y = pos.y + 0.5 -- Raise slightly above ground
            minetest.add_entity(pos, "moon:ant")
            minetest.chat_send_player(placer:get_player_name(), 
                "Component assembly complete! Rover unit activated.")
            
            -- Consume the component kit
            itemstack:take_item()
            return itemstack
        else
            minetest.chat_send_player(placer:get_player_name(), 
                "Cannot assemble rover: No fabrication hub with sufficient power nearby!")
            return itemstack
        end
    end
})

-------------------------------------------------
-- Electroplating Fabricator - manufactures rover components
-------------------------------------------------
minetest.register_node("moon:fabricator", {
    description = "Electroplating Fabricator",
    tiles = {"moon_fabricator_top.png", "moon_fabricator_bottom.png", "moon_fabricator_side.png"},
    paramtype2 = "facedir",
    groups = {cracky=2, machine=1},
    
    on_construct = function(pos)
        local meta = minetest.get_meta(pos)
        meta:set_string("infotext", "Electroplating Fabricator (Idle)")
        
        -- Create an empty formspec for the fabricator
        meta:set_string("formspec", 
            "size[8,8]" ..
            "label[2.5,0;Electroplating Fabricator]" ..
            "label[0,1;Status: Idle]" ..
            "button[3,2;2,1;create;Create Components]" ..
            "label[0,3;Process: Electrolytic Deposition]" ..
            "label[0,4;Material Requirements:]" ..
            "label[1,4.5;• 2 Regolith (silicon substrate)]" ..
            "label[1,5.0;• 1 Metal (conductive layers)]" ..
            "label[1,5.5;• 5 EU (for electroplating)]" ..
            "label[0,6.5;Ice needed for phosphoric acid electrolyte]"
        )
    end,
    
    on_receive_fields = function(pos, formname, fields, sender)
        if fields.create then
            local meta = minetest.get_meta(pos)
            local player_name = sender:get_player_name()
            
            -- Check nearby fabrication hubs for resources
            local hubs = minetest.find_nodes_in_area(
                {x=pos.x-5, y=pos.y-5, z=pos.z-5},
                {x=pos.x+5, y=pos.y+5, z=pos.z+5},
                {"moon:nest_core"}
            )
            
            local hub_pos = nil
            local has_resources = false
            
            for _, np in ipairs(hubs) do
                local hub_meta = minetest.get_meta(np)
                local regolith = hub_meta:get_int("regolith")
                local metal = hub_meta:get_int("metal")
                local ice = hub_meta:get_int("ice")
                local energy = moon_energy.get(np)
                
                -- Need ice for the electrolyte solution (phosphoric acid from lunar phosphorus)
                if regolith >= 2 and metal >= 1 and energy >= 5 and ice >= 1 then
                    -- Found a hub with enough resources
                    hub_pos = np
                    has_resources = true
                    break
                end
            end
            
            if has_resources then
                -- Consume resources from the hub
                local hub_meta = minetest.get_meta(hub_pos)
                hub_meta:set_int("regolith", hub_meta:get_int("regolith") - 2)
                hub_meta:set_int("metal", hub_meta:get_int("metal") - 1)
                hub_meta:set_int("ice", hub_meta:get_int("ice") - 1)
                moon_energy.take(hub_pos, 5)
                
                -- Update hub infotext
                local regolith = hub_meta:get_int("regolith")
                local metal = hub_meta:get_int("metal")
                local ice = hub_meta:get_int("ice")
                local energy = moon_energy.get(hub_pos)
                hub_meta:set_string("infotext", string.format(
                    "Fabrication Hub\nRegolith: %d\nMetal: %d\nIce: %d\nEnergy: %d EU",
                    regolith, metal, ice, energy
                ))
                
                -- Create the rover component kit
                local inv = sender:get_inventory()
                if inv:room_for_item("main", "moon:component_kit") then
                    inv:add_item("main", "moon:component_kit")
                    minetest.chat_send_player(player_name, 
                        "Electroplating complete! Component kit fabricated with silicon circuitry and metal parts.")
                    
                    -- Show fabrication process status
                    meta:set_string("infotext", "Electroplating Fabricator (Electrodeposition in Progress)")
                    minetest.after(1, function()
                        meta:set_string("infotext", "Electroplating Fabricator (Etching Circuits)")
                    end)
                    minetest.after(2, function()
                        meta:set_string("infotext", "Electroplating Fabricator (Forming Metal Components)")
                    end)
                    minetest.after(3, function()
                        meta:set_string("infotext", "Electroplating Fabricator (Idle)")
                    end)
                else
                    -- Return resources to hub if inventory is full
                    hub_meta:set_int("regolith", hub_meta:get_int("regolith") + 2)
                    hub_meta:set_int("metal", hub_meta:get_int("metal") + 1)
                    hub_meta:set_int("ice", hub_meta:get_int("ice") + 1)
                    moon_energy.add(hub_pos, 5)
                    minetest.chat_send_player(player_name, "Your inventory is full!")
                end
            else
                minetest.chat_send_player(player_name, 
                    "Not enough resources in nearby fabrication hub! Need 2 regolith, 1 metal, 1 ice and 5 EU.")
            end
        end
    end
})