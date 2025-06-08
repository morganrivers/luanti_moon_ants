local S = minetest.get_translator("moon")

local bond_types = {
    ["moon:rigid_bond"] = moon.BOND.RIGID,
    ["moon:electric_bond"] = moon.BOND.ELECTRIC,
    ["moon:shaft_bond"] = moon.BOND.SHAFT,
}

local electric_r_values = {0, 10, 100, 1000}
local function get_next_r(current_r)
    for i, r in ipairs(electric_r_values) do
        if r == current_r then
            return electric_r_values[(i % #electric_r_values) + 1]
        end
    end
    return electric_r_values[1]
end

local function find_bond_faces(pos)
    local dirs = {
        {name="x+", v={x=1, y=0, z=0}},
        {name="x-", v={x=-1, y=0, z=0}},
        {name="y+", v={x=0, y=1, z=0}},
        {name="y-", v={x=0, y=-1, z=0}},
        {name="z+", v={x=0, y=0, z=1}},
        {name="z-", v={x=0, y=0, z=-1}},
    }
    local faces = {}
    for _, d in ipairs(dirs) do
        local npos = vector.add(pos, d.v)
        local nname = minetest.get_node(npos).name
        if nname ~= "air" and nname ~= "ignore" then
            table.insert(faces, {dir=d.v, pos=npos})
        end
    end
    return faces
end

local function are_opposite(f1, f2)
    return (f1.dir.x == -f2.dir.x and f1.dir.y == -f2.dir.y and f1.dir.z == -f2.dir.z)
end

local function show_warn(pos, player)
    minetest.chat_send_player(player:get_player_name(), S("Bond must be placed between exactly two opposite voxels."))
    minetest.sound_play("moon_error", {pos=pos, max_hear_distance=8, gain=0.5})
end

local function handle_bond_construct(pos, node, placer, itemstack, pointed_thing)
    local bond_type = bond_types[node.name]
    if not bond_type then return end

    local faces = find_bond_faces(pos)
    if #faces ~= 2 or not are_opposite(faces[1], faces[2]) then
        if placer and placer:is_player() then
            show_warn(pos, placer)
        end
        minetest.remove_node(pos)
        return
    end

    local state
    if bond_type == moon.BOND.ELECTRIC then
        local meta = minetest.get_meta(pos)
        local r = meta:get_int("R") or 0
        state = {R = r}
    elseif bond_type == moon.BOND.SHAFT then
        state = {ratio = 1.0, omega_rpm = 0, torque_Nm = 0}
    else
        state = {}
    end

    bonds.api.create(faces[1].pos, faces[2].pos, bond_type, state)
    minetest.remove_node(pos)
end

local function electric_bond_on_place(itemstack, placer, pointed_thing)
    local pos = pointed_thing.above
    local under = pointed_thing.under
    if not placer or not pos then return minetest.item_place(itemstack, placer, pointed_thing) end

    local sneak = placer:get_player_control().sneak
    if sneak then
        local r = itemstack:get_meta():get_int("R") or 0
        r = get_next_r(r)
        itemstack:get_meta():set_int("R", r)
        minetest.chat_send_player(placer:get_player_name(), S("Electric Bond R set to: @1 Ω", tostring(r)))
        return itemstack
    end

    local meta = minetest.get_meta(pos)
    local item_r = itemstack:get_meta():get_int("R") or 0
    meta:set_int("R", item_r)

    return minetest.item_place(itemstack, placer, pointed_thing)
end

minetest.register_node("moon:rigid_bond", {
    description = S("Rigid Bond"),
    drawtype = "nodebox",
    tiles = {"moon_bond_rigid.png"},
    groups = {cracky=3, oddly_breakable_by_hand=3, not_in_creative_inventory=1},
    paramtype = "light",
    sunlight_propagates = true,
    node_box = {
        type = "fixed",
        fixed = {-0.5, -0.0625, -0.5, 0.5, 0.0625, 0.5},
    },
    on_construct = function(pos)
        minetest.after(0, function()
            local node = minetest.get_node(pos)
            handle_bond_construct(pos, node)
        end)
    end,
})

minetest.register_node("moon:electric_bond", {
    description = S("Electric Bond"),
    drawtype = "nodebox",
    tiles = {"moon_bond_electric.png"},
    groups = {cracky=3, oddly_breakable_by_hand=3, not_in_creative_inventory=1},
    paramtype = "light",
    sunlight_propagates = true,
    node_box = {
        type = "fixed",
        fixed = {-0.5, -0.03125, -0.5, 0.5, 0.03125, 0.5},
    },
    on_construct = function(pos)
        minetest.after(0, function()
            local node = minetest.get_node(pos)
            handle_bond_construct(pos, node)
        end)
    end,
    on_place = electric_bond_on_place,
})

minetest.register_node("moon:shaft_bond", {
    description = S("Shaft Bond"),
    drawtype = "nodebox",
    tiles = {"moon_bond_shaft.png"},
    groups = {cracky=3, oddly_breakable_by_hand=3, not_in_creative_inventory=1},
    paramtype = "light",
    sunlight_propagates = true,
    node_box = {
        type = "fixed",
        fixed = {-0.5, -0.03125, -0.5, 0.5, 0.03125, 0.5},
    },
    on_construct = function(pos)
        minetest.after(0, function()
            local node = minetest.get_node(pos)
            handle_bond_construct(pos, node)
        end)
    end,
})
