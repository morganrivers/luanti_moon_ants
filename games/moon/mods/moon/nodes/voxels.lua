
local minetest = minetest
local constants = constants
local materials = materials
local moon = moon
local util = util
local voxels = voxels
local ports = ports
local bonds = bonds

-- local voxels = dofile(minetest.get_modpath("moon") .. "/nodes/voxels.lua")

local bit = dofile(minetest.get_modpath("moon") .. "/lib/bit.lua")

local MATERIALS = {
    conductor = {id = materials.registry.get("Cu").id, flags = materials.flags.CONDUCTOR, desc = "Conductor Voxel"},
    insulator = {id = materials.registry.get("C").id, flags = materials.flags.INSULATOR, desc = "Insulator Voxel"},
    powder = {id = materials.registry.get("Vac").id, flags = materials.flags.POWDER, desc = "Powder Voxel"},
    wheel = {id = materials.registry.get("Steel").id, flags = materials.flags.WHEEL, desc = "Wheel Voxel"},
    shaft = {id = materials.registry.get("Steel").id, flags = materials.flags.SHAFT, desc = "Shaft Voxel"},
    capacitor = {id = materials.registry.get("C").id, flags = materials.flags.CAPACITOR, desc = "Capacitor Voxel"},
}

local NODEBOX = {
    type = "fixed",
    fixed = { 
        -constants.VOXEL_EDGE/2, -constants.VOXEL_EDGE/2, -constants.VOXEL_EDGE/2,
         constants.VOXEL_EDGE/2,  constants.VOXEL_EDGE/2,  constants.VOXEL_EDGE/2,
    }
}

local function make_meta(material_id, flags)
    return {
        flags = flags,
        material_id = material_id,
        port_id = 0,
        temperature = constants.DEFAULT_T,
    }
end

local function spawn_port(pos_hash, face, class, state)
    return ports.registry.add(pos_hash, face, class, state)
end

local function auto_electric_bond(pos)
    local dirs = {
        {x= 1,y= 0,z= 0}, {x=-1,y= 0,z= 0},
        {x= 0,y= 1,z= 0}, {x= 0,y=-1,z= 0},
        {x= 0,y= 0,z= 1}, {x= 0,y= 0,z=-1}
    }
    local pos_hash = util.hash(pos)
    for _, dir in ipairs(dirs) do
        local adj = {x=pos.x+dir.x, y=pos.y+dir.y, z=pos.z+dir.z}
        local n = minetest.get_node_or_nil(adj)
        if n then
            local meta = voxels.metadata.read(adj)
            if meta and bit.band(meta.flags, materials.flags.CONDUCTOR) ~= 0 then
            -- if meta and (meta.flags & materials.flags.CONDUCTOR) ~= 0 then
                bonds.api.create(pos_hash, util.hash(adj), moon.BOND.ELECTRIC, {C=1e-6})
            end
        end
    end
end

minetest.register_node("moon:conductor_voxel", {
    description = MATERIALS.conductor.desc,
    drawtype = "nodebox",
    node_box = NODEBOX,
    paramtype = "light",
    groups = {moon_voxel=1},
    on_construct = function(pos)
        local meta = make_meta(MATERIALS.conductor.id, MATERIALS.conductor.flags)
        voxels.metadata.write(pos, meta)
        -- start timer to update actuator infotext when hovering
        local node_meta = minetest.get_meta(pos)
        node_meta:set_string("infotext", MATERIALS.conductor.desc)
        minetest.get_node_timer(pos):start(1)
    end,
    on_timer = function(pos, elapsed)

        local pos_hash = util.hash(pos)
        local node_meta = minetest.get_meta(pos)
        for port_id in ports.registry.ports_for_voxel(pos_hash) do
            local port = ports_registry.lookup(port_id)
            minetest.log("action", ("[cond] port_id=%d  class=%d  cmd=%s")
                        :format(port_id, port and port.class or -1,
                                port and tostring(port.state.command)))

            local port = ports.registry.lookup(port_id)
            if port and port.class == moon.PORT.ACTUATOR then
                minetest.log("action", string.format("[moon]:port.state.command %.1f", port.state.command))
                -- node_meta:set_string("infotext", string.format("Wheel\nRPM: %.1f", rpm))

                local cmd = port.state.command or 0
                node_meta:set_string("infotext",
                    string.format("Actuator\nCmd: %d", cmd))
                break
            end
        end
        return true
    end,
})

minetest.register_node("moon:insulator_voxel", {
    description = MATERIALS.insulator.desc,
    drawtype = "nodebox",
    node_box = NODEBOX,
    paramtype = "light",
    groups = {moon_voxel=1},
    on_construct = function(pos)
        local meta = make_meta(MATERIALS.insulator.id, MATERIALS.insulator.flags)
        voxels.metadata.write(pos, meta)
    end
})

minetest.register_node("moon:powder_voxel", {
    description = MATERIALS.powder.desc,
    drawtype = "nodebox",
    node_box = NODEBOX,
    paramtype = "light",
    groups = {moon_voxel=1},
    on_construct = function(pos)
        local meta = make_meta(MATERIALS.powder.id, MATERIALS.powder.flags)
        voxels.metadata.write(pos, meta)
    end
})

minetest.register_node("moon:wheel_voxel", {
    description = MATERIALS.wheel.desc,
    drawtype = "nodebox",
    node_box = NODEBOX,
    paramtype = "light",
    groups = {moon_voxel=1},
    on_construct = function(pos)
        local existing = voxels.metadata.read(pos)
        if existing and (existing.flags or 0) ~= 0 then
            return                      -- ← early-exit
        end

        local m = make_meta(MATERIALS.wheel.id, MATERIALS.wheel.flags)
        if not m then
            print("We had a nil m!")
            return
        end
        -- if m:get_int("moon_init") == 1 then
        --     return                -- already initialised
        -- end
        -- if (m.read(pos) or {}).flags ~= nil then
        --     return        -- already initialised; avoid duplicate wheel
        -- end
        voxels.metadata.write(pos, m)
        -- spawn actuator or sensor port for omega
        local pos_hash = util.hash(pos)
        -- spawn_port(pos_hash, 0, moon.PORT.ACTUATOR, {omega=0})
        spawn_port(pos_hash, 0, moon.PORT.SENSOR, {omega=0})
        -- initial infotext and start timer for updating rotation rate
        local node_meta = minetest.get_meta(pos)
        node_meta:set_string("infotext", "Wheel\nRPM: 0")
        minetest.get_node_timer(pos):start(1)
    end,
    on_timer = function(pos, elapsed)
        minetest.log("action", ("[wheel] timer fired"))

        local pos_hash = util.hash(pos)
        local rpm = 0
        for _, bond in bonds.registry.pairs_for_voxel(pos_hash) do
            if bond.type == bonds.types.SHAFT then
                rpm = bond.omega_rpm or rpm
                break
            end
        end
        minetest.log("action", ("[wheel] voxel %08x rpm %.2f")
                     :format(pos_hash, rpm))
        -- wheel on_timer (after reading rpm)
        minetest.log("action", ("[wheel] final rpm on node = %.1f"):format(rpm))

        -- nodes/voxels.lua : wheel on_timer
        minetest.log("action",
          ("[wheel] reporting %.1f rpm from bond"):format(rpm))
        local node_meta = minetest.get_meta(pos)
        node_meta:set_string("infotext", string.format("Wheel\nRPM: %.1f", rpm))
        return true
    end,
})

minetest.register_node("moon:shaft_voxel", {
    description = MATERIALS.shaft.desc,
    drawtype = "nodebox",
    node_box = NODEBOX,
    paramtype = "light",
    groups = {moon_voxel=1},
    on_construct = function(pos)
        local meta = make_meta(MATERIALS.shaft.id, MATERIALS.shaft.flags)
        voxels.metadata.write(pos, meta)
        local node_meta = minetest.get_meta(pos)
        node_meta:set_string("infotext", MATERIALS.shaft.desc)
    end
})

minetest.register_node("moon:capacitor_voxel", {
    description = MATERIALS.capacitor.desc,
    drawtype = "nodebox",
    node_box = NODEBOX,
    paramtype = "light",
    groups = {moon_voxel=1},
    on_construct = function(pos)
        local meta = make_meta(MATERIALS.capacitor.id, MATERIALS.capacitor.flags)
        voxels.metadata.write(pos, meta)
        auto_electric_bond(pos)
    end
})
