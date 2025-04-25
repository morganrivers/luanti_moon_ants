--
-- moon/resources.lua
--  • Basic in‑situ resources the ants must mine
--

local S = minetest.get_translator("moon")


-------------------------------------------------
-- 1. Regolith (already present as moon:regolith)
-------------------------------------------------
-- we just make sure it belongs to the group "regolith"
minetest.override_item("moon:regolith", {groups = {cracky = 3, regolith = 1}})

-------------------------------------------------
-- 2. Metal‑bearing rock   (Fe, Ti‑rich ilmenite, etc.)
-------------------------------------------------
minetest.register_node("moon:metal_ore", {
    description    = S("Metal‑Bearing Regolith"),
    tiles          = {"moon_regolith.png^(moon_ore_metal.png)"},
    is_ground_content = true,
    groups         = {cracky = 3, metal_ore = 1},
    drop           = "moon:metal_piece",
    sounds         = default.node_sound_stone_defaults(),
})

minetest.register_craftitem("moon:metal_piece", {
    description = S("Metal Piece"),
    inventory_image = "moon_metal_piece.png",
})

-------------------------------------------------
-- 3. Water‑ice boulder (H₂ source, coolant)
-------------------------------------------------
minetest.register_node("moon:ice_rock", {
    description = S("Sub‑Surface Ice Boulder"),
    tiles       = {"moon_ice_rock.png"},
    is_ground_content = true,
    groups      = {cracky = 3, ice_rock = 1},
    drop        = "moon:ice_chunk",
    sounds      = default.node_sound_glass_defaults(),
    light_source = 2,  -- Faint glow to make it more visible (represents reflectivity)
    -- melts to nothing if exposed to sunlight
    on_construct = function(pos)
        if minetest.get_node_light(pos, 0.5) and minetest.get_node_light(pos, 0.5) > 13 then
            minetest.remove_node(pos)
        end
        
        -- Emit particles occasionally when constructed (condensation effect)
        minetest.add_particlespawner({
            amount = 10,
            time = 2,
            minpos = {x=pos.x-0.4, y=pos.y-0.4, z=pos.z-0.4},
            maxpos = {x=pos.x+0.4, y=pos.y+0.4, z=pos.z+0.4},
            minvel = {x=-0.1, y=0.1, z=-0.1},
            maxvel = {x=0.1, y=0.2, z=0.1},
            minacc = {x=0, y=0, z=0},
            maxacc = {x=0, y=0, z=0},
            minexptime = 1,
            maxexptime = 2,
            minsize = 0.5,
            maxsize = 1,
            collisiondetection = false,
            texture = "moon_ice_particle.png",
        })
    end,
    
    -- Add periodic vapor emission for existing ice blocks
    on_timer = function(pos)
        -- Only emit particles if in darkness (simulating cold trap environment)
        if not minetest.get_node_light(pos, 0.5) or minetest.get_node_light(pos, 0.5) < 8 then
            minetest.add_particlespawner({
                amount = 5,
                time = 1,
                minpos = {x=pos.x-0.4, y=pos.y-0.4, z=pos.z-0.4},
                maxpos = {x=pos.x+0.4, y=pos.y+0.4, z=pos.z+0.4},
                minvel = {x=-0.1, y=0.1, z=-0.1},
                maxvel = {x=0.1, y=0.2, z=0.1},
                minacc = {x=0, y=0, z=0},
                maxacc = {x=0, y=0, z=0},
                minexptime = 1,
                maxexptime = 2,
                minsize = 0.5,
                maxsize = 1,
                collisiondetection = false,
                texture = "moon_ice_particle.png",
            })
        end
        
        -- Continue timer
        minetest.get_node_timer(pos):start(math.random(10, 30))
        return true
    end,
    
    -- Start the timer when node is placed
    after_place_node = function(pos, placer)
        minetest.get_node_timer(pos):start(math.random(10, 30))
    end,
})

minetest.register_craftitem("moon:ice_chunk", {
    description = S("Water‑Ice Chunk"),
    inventory_image = "moon_ice_chunk.png",
})

-------------------------------------------------
-- 4. Map‑gen helper – distributed resources throughout the terrain
-------------------------------------------------

-- Metal ore distribution
-- Primary metal veins in mid-depths (common)
minetest.register_ore({
    ore_type       = "scatter",
    ore            = "moon:metal_ore",
    wherein        = "moon:regolith",
    clust_scarcity = 14*14*14,  -- More common
    clust_num_ores = 9,
    clust_size     = 3,         -- Medium clusters
    y_min          = -64,
    y_max          = -4,        -- Closer to surface
})

-- Shallow metal deposits scattered throughout (very common)
minetest.register_ore({
    ore_type       = "scatter",
    ore            = "moon:metal_ore",
    wherein        = {"moon:regolith", "moon:light_regolith"},
    clust_scarcity = 12*12*12,  -- Very common
    clust_num_ores = 3,
    clust_size     = 2,         -- Smaller clusters
    y_min          = -25,
    y_max          = -1,        -- Almost at surface
})

-- Rare, rich metal deposits at depth
minetest.register_ore({
    ore_type       = "scatter",
    ore            = "moon:metal_ore",
    wherein        = {"moon:bedrock", "moon:dark_regolith"},
    clust_scarcity = 20*20*20,  -- Quite rare but more common than before
    clust_num_ores = 12,
    clust_size     = 4,         -- Larger, rich deposits
    y_min          = -100,
    y_max          = -32,
})

-- Ice distribution
-- Ice pockets underground (more common)
minetest.register_ore({
    ore_type       = "scatter",
    ore            = "moon:ice_rock",
    wherein        = "moon:regolith",
    clust_scarcity = 18*18*18,  -- More common
    clust_num_ores = 6,
    clust_size     = 2,
    y_min          = -64,
    y_max          = -8,
})

-- Concentrated ice in dark areas (very common)
minetest.register_ore({
    ore_type       = "scatter",
    ore            = "moon:ice_rock",
    wherein        = {"moon:dark_regolith"},  -- In dark areas
    clust_scarcity = 10*10*10,   -- Very common in dark regolith
    clust_num_ores = 8,
    clust_size     = 3,
    y_min          = -40,
    y_max          = -2,
})

-- Deep ice pockets (ancient deposits)
minetest.register_ore({
    ore_type       = "scatter",
    ore            = "moon:ice_rock",
    wherein        = {"moon:bedrock", "moon:dark_regolith"},
    clust_scarcity = 16*16*16,   -- Common at depth
    clust_num_ores = 8,
    clust_size     = 4,         -- Larger deposits
    y_min          = -100,
    y_max          = -30,
})

-- Shallow hidden ice pockets (rare but valuable finds)
minetest.register_ore({
    ore_type       = "scatter",
    ore            = "moon:ice_rock",
    wherein        = "moon:regolith",
    clust_scarcity = 35*35*35,  -- Rare near surface
    clust_num_ores = 4,
    clust_size     = 2,         -- Small deposits
    y_min          = -20,
    y_max          = -1,        -- Near surface
})

-- Regolith variations (for resource diversity)
minetest.register_ore({
    ore_type       = "scatter",
    ore            = "moon:light_regolith",
    wherein        = "moon:regolith",
    clust_scarcity = 10*10*10,  -- Very common
    clust_num_ores = 12,
    clust_size     = 5,
    y_min          = -70,
    y_max          = 0,
})

-- Dark regolith patches (potential ice indicators)
minetest.register_ore({
    ore_type       = "scatter",
    ore            = "moon:dark_regolith",
    wherein        = "moon:regolith",
    clust_scarcity = 15*15*15,
    clust_num_ores = 8,
    clust_size     = 4,
    y_min          = -50,
    y_max          = -2,
})

-- Mixed metal-ice deposits (valuable finds)
minetest.register_ore({
    ore_type       = "scatter",
    ore            = "moon:ice_rock",
    wherein        = {"moon:metal_ore"},
    clust_scarcity = 20*20*20,  -- Reasonably common when you find metal
    clust_num_ores = 3,
    clust_size     = 2,
    y_min          = -80,
    y_max          = -10,
})


minetest.register_node("moon:nest_core", {
    description = "Fabrication Hub",
    tiles = {"moon_nest_core.png"},
    groups = {cracky = 1, oddly_breakable_by_hand = 2, nest_core = 1},
    sounds = default.node_sound_stone_defaults(),
    light_source = 2,
    
    -- Initialize the inventory counters and energy when placed
    on_construct = function(pos)
        local meta = minetest.get_meta(pos)
        meta:set_int("regolith", 0)
        meta:set_int("metal", 0)
        meta:set_int("ice", 0)
        -- Set some initial energy if moon_energy exists
        if moon_energy then
            moon_energy.add(pos, 100)
        end
        meta:set_string("infotext", "Fabrication Hub\nResource Storage Empty")
        minetest.get_node_timer(pos):start(10)

    end,
    
    -- periodic check for auto‐replication
    on_timer = function(pos, elapsed)
        local meta    = minetest.get_meta(pos)
        local sil     = meta:get_int("regolith")
        minetest.log("action", "[moon:nest_core] Timer tick at " .. minetest.pos_to_string(pos) .. ", silicon = " .. sil)
        -- only replicate if we have enough silicon
        if sil >= 10 then
            -- look for an adjacent free spot (horizontal only)
            local offsets = {
                {x= 1, y=0, z= 0}, {x=-1, y=0, z= 0},
                {x= 0, y=0, z= 1}, {x= 0, y=0, z=-1},
                {x= 1, y=0, z= 1}, {x=-1, y=0, z= 1},
                {x= 1, y=0, z=-1}, {x=-1, y=0, z=-1},
            }
            for _, off in ipairs(offsets) do
                local p = vector.add(pos, off)
                local name = minetest.get_node(p).name
                if minetest.get_node(p).name == "air" then
                    -- place new hub
                    minetest.set_node(p, {name = "moon:nest_core"})
                    -- initialize its meta exactly as on_construct
                    local newm = minetest.get_meta(p)
                    newm:set_int("regolith", 0)
                    newm:set_int("metal",    0)
                    newm:set_int("ice",      0)
                    if moon_energy then
                        moon_energy.add(p, 100)
                    end

                    newm:set_string("infotext", "Fabrication Hub\nResource Storage Empty")
                    -- consume 10 silicon from the parent hub
                    meta:set_int("regolith", sil - 10)
                    -- update its infotext
                    meta:set_string("infotext",
                      string.format("Fabrication Hub\nRegolith: %d/10", sil - 10))

                    minetest.log("action", "[moon:nest_core] Replicated to " .. minetest.pos_to_string(p))
                    replicated = true
                    break
                else
                    minetest.log("info", "[moon:nest_core] Position " .. minetest.pos_to_string(p) .. " blocked by: " .. name)
                end
            end
            if not replicated then
                minetest.log("warning", "[moon:nest_core] No free space to replicate from " .. minetest.pos_to_string(pos))
                print("[moon:nest_core] No free space to replicate from " .. minetest.pos_to_string(pos))
            end
        else
            minetest.log("info", "[moon:nest_core] Not enough silicon (" .. sil .. "/10) at " .. minetest.pos_to_string(pos))
        end
        -- always return true to keep the timer running
        return true
    end,

    -- Right-click to see inventory
    on_rightclick = function(pos, node, clicker, itemstack)
        local meta = minetest.get_meta(pos)
        local regolith = meta:get_int("regolith")
        local metal = meta:get_int("metal")
        local ice = meta:get_int("ice")
        local energy = moon_energy and moon_energy.get(pos) or 0
        
        -- Update infotext
        meta:set_string("infotext", string.format(
            "Fabrication Hub\nRegolith: %d\nMetal: %d\nIce: %d\nEnergy: %d EU",
            regolith, metal, ice, energy
        ))
        
        -- Send message to player
        minetest.chat_send_player(clicker:get_player_name(), string.format(
            "Fabrication Hub Resource Storage:\n* Silicon Base (Regolith): %d\n* Conductive Metal: %d\n* Ice (for Electrolyte): %d\n* Energy Reserves: %d EU",
            regolith, metal, ice, energy
        ))
    end
})