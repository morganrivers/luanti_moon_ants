minetest.register_alias("mapgen_water_source", "air")
minetest.register_alias("mapgen_river_water_source", "air")
minetest.register_alias("mapgen_lava_source", "air")

-- Set the mapgen to singlenode to prevent default terrain generation
minetest.set_mapgen_setting("mg_name", "singlenode", true)

-- Create a flat regolith surface at y=0
minetest.register_on_generated(function(minp, maxp, blockseed)
    if minp.y <= 0 and maxp.y >= 0 then
        local vm = minetest.get_mapgen_object("voxelmanip")
        local emin, emax = vm:get_emerged_area()
        local area = VoxelArea:new{MinEdge=emin, MaxEdge=emax}
        local data = vm:get_data()
        
        local c_regolith = minetest.get_content_id("moon:regolith")
        
        -- Create a flat surface at y=0
        for z = minp.z, maxp.z do
            for x = minp.x, maxp.x do
                local vi = area:index(x, 0, z)
                data[vi] = c_regolith
                
                -- Add some depth below the surface
                for y = minp.y, math.min(-1, maxp.y) do
                    vi = area:index(x, y, z)
                    data[vi] = c_regolith
                end
            end
        end
        
        vm:set_data(data)
        vm:write_to_map()
    end
end)

minetest.register_biome({
    name = "moon_regolith",
    node_top = "moon:regolith",
    depth_top = 1,
    node_filler = "moon:regolith",
    depth_filler = 3,
    y_max = 1000,
    y_min = -31000,
    heat_point = 0,
    humidity_point = 0,
})

-- Disabled until schematic is available
-- minetest.register_decoration({
--     deco_type = "schematic",
--     biomes = {"moon_regolith"},
--     y_max = -100,
--     y_min = -31000,
--     sidelen = 80,
--     fill_ratio = 0.0002,
--     schematic = minetest.get_modpath("moon") .. "/schems/ice_patch.mts",
-- })
	
