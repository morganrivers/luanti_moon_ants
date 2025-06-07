minetest.register_on_joinplayer(function(player)
    player:set_physics_override({ gravity = 0.1 })
    player:set_clouds({density = 0})
    
    -- Set a visible sky color
    player:set_sky({
        type = "regular",
        clouds = false,
        sky_color = {
            day_sky = "#000000",
            day_horizon = "#6A89BD",
            dawn_sky = "#0E1D30",
            dawn_horizon = "#4A68A0", 
            night_sky = "#000000",
            night_horizon = "#000524"
        }
    })
    
    -- Add sun and stars
    player:set_sun({
        visible = true,
        scale = 1
    })
    
    -- Set the time to daytime
    minetest.set_timeofday(0.5)
    
    -- Increase light level
    player:override_day_night_ratio(1.0)
    
    -- Fix spawn position if underground
    minetest.after(0.5, function()
        local pos = player:get_pos()
        if pos.y < 0 then
            -- Spawn the player above ground
            player:set_pos({x=0, y=5, z=0})
            -- Ensure there's ground to stand on
            minetest.set_node({x=0, y=0, z=0}, {name="moon:regolith"})
            minetest.set_node({x=1, y=0, z=0}, {name="moon:regolith"})
            minetest.set_node({x=0, y=0, z=1}, {name="moon:regolith"})
            minetest.set_node({x=-1, y=0, z=0}, {name="moon:regolith"})
            minetest.set_node({x=0, y=0, z=-1}, {name="moon:regolith"})
        end
    end)
end)