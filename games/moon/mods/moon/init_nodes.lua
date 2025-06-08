local mp = minetest.get_modpath(minetest.get_current_modname())
dofile(mp.."/materials/seed.lua")
for _,f in ipairs({
  "nodes/voxels.lua",
  "nodes/dev_items.lua",
  "nodes/bonds.lua",
  "schematics/demo_blueprints.lua"
}) do
  dofile(mp.."/"..f)
end
