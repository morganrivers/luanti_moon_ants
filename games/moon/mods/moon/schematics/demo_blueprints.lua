-- Use global objects instead of loading individual modules
local MATERIAL = moon.MATERIAL
local materials_registry = moon.materials
local BOND = moon.BOND
local PORT = moon.PORT

local function px(pos, x, y, z)
    return {x=pos.x + x, y=pos.y + y, z=pos.z + z}
end

local function place_rc_demo(pos)
    -- Place three conductor voxels in a +X line, assign correct meta
    local p1 = px(pos,0,0,0)
    local p2 = px(pos,1,0,0)
    local p3 = px(pos,2,0,0)
    minetest.set_node(p1, {name="moon:conductor_voxel"})
    minetest.set_node(p2, {name="moon:conductor_voxel"})
    minetest.set_node(p3, {name="moon:conductor_voxel"})
    -- Set voxel metadata (conductor, material)
    voxels.metadata.write(p1, {flags=MATERIAL.Cu, material_id=MATERIAL.Cu})
    voxels.metadata.write(p2, {flags=MATERIAL.Cu, material_id=MATERIAL.Cu})
    voxels.metadata.write(p3, {flags=MATERIAL.Cu, material_id=MATERIAL.Cu})
    -- R-bond 1-2 (100 Ω)
    bonds.api.create(p1, 1, p2, 0, BOND.ELECTRICAL, {resistance_ohm=100})
    -- C-bond 2-3 (1 mF)
    bonds.api.create(p2, 1, p3, 0, BOND.ELECTRICAL, {capacitance_f=0.001})
    -- Add POWER port to voxel 1 (voltage=5)
    moon.ports.add(util.hash(p1), 0, PORT.POWER, {voltage=5})
    -- Add POWER port to voxel 3 (voltage=0, current_A=0)
    moon.ports.add(util.hash(p3), 0, PORT.POWER, {voltage=0, current_A=0})
end

local function place_wheel_demo(pos)
    -- Place motor coil (conductor+ACTUATOR), shaft, wheel
    local p1 = px(pos,0,0,0)
    local p2 = px(pos,1,0,0)
    local p3 = px(pos,2,0,0)
    minetest.set_node(p1, {name="moon:conductor_voxel"})
    minetest.set_node(p2, {name="moon:shaft_voxel"})
    minetest.set_node(p3, {name="moon:wheel_voxel"})
    voxels.metadata.write(p1, {flags=MATERIAL.Cu, material_id=MATERIAL.Cu})
    do
        local steel_id = materials_registry.get("Steel").id
        voxels.metadata.write(p2, {
            flags       = MATERIAL.SHAFT,
            material_id = steel_id,
        })
        voxels.metadata.write(p3, {
            flags       = MATERIAL.WHEEL,
            material_id = steel_id,
        })
    end
    -- Add ACTUATOR port to coil (command=100)
    -- moon.ports.add(util.hash(p1), 0, PORT.ACTUATOR, {command=100})
    -- After the ACTUATOR port
    -- moon.ports.add(util.hash(p1), 0, PORT.POWER, {voltage = 12, current_A = 3})
    -- SHAFT bond coil <-> shaft, shaft <-> wheel
    moon.ports.add(util.hash(p2), 0, PORT.ACTUATOR, {command = 100})
    bonds.api.create(p1, 1, p2, 0, BOND.SHAFT, {ratio=1})
    bonds.api.create(p2, 1, p3, 0, BOND.SHAFT, {ratio=1})
    
    -- -- Manually trigger island detection
    -- minetest.log("action", "[moon] Manually triggering island scan...")
    -- local detector = moon.islands.detector
    -- local all_islands = detector.scan_all()
    -- minetest.log("action", "[moon] Found " .. #all_islands .. " islands after demo creation")
end

return {
    place_rc_demo = place_rc_demo,
    place_wheel_demo = place_wheel_demo
}
