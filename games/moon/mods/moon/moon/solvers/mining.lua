```lua
dofile(minetest.get_modpath("moon") .. "/constants.lua")
dofile(minetest.get_modpath("moon") .. "/util.lua")
dofile(minetest.get_modpath("moon") .. "/materials/registry.lua")
dofile(minetest.get_modpath("moon") .. "/bonds/registry.lua")
dofile(minetest.get_modpath("moon") .. "/ports/registry.lua")
dofile(minetest.get_modpath("moon") .. "/ports/api.lua")
dofile(minetest.get_modpath("moon") .. "/voxels/metadata.lua")

local mining = {}

-- Helper: get the face vector for a given face index (0..5)
local FACE_VECTORS = {
  [0] = { x =  1, y =  0, z =  0 }, -- +X
  [1] = { x = -1, y =  0, z =  0 }, -- -X
  [2] = { x =  0, y =  1, z =  0 }, -- +Y
  [3] = { x =  0, y = -1, z =  0 }, -- -Y
  [4] = { x =  0, y =  0, z =  1 }, -- +Z
  [5] = { x =  0, y =  0, z = -1 }, -- -Z
}

-- Helper: is this node flagged as ore? (for demo, use node group 'ore')
local function is_ore_node(node_name)
  local def = minetest.registered_nodes[node_name]
  if def and def.groups and def.groups.ore then
    return true
  end
  return false
end

-- Helper: spawn an ore item entity at pos with ore_type metadata
local function spawn_ore_item(pos, ore_type)
  local itemstack = ItemStack(ore_type)
  local obj = minetest.add_item(pos, itemstack)
  if obj and obj:get_luaentity() then
    obj:get_luaentity()._moon_ore_type = ore_type
  end
end

-- The main mining solver step
function mining.step(island, dt)
  local dirty = false

  for port_id, port_rec in pairs(island.ports) do
    local port = ports.lookup(port_id)
    if port and port.class == ports.types.MINE_TOOL then
      local state = port.state
      local torque = state.torque or 0
      if torque > 0 and (state.hardness or 0) > 0 then
        -- Find voxel and face this port is on
        local pos_hash = port.pos_hash
        local face     = port.face
        -- Decode position
        local pos = util.unhash(pos_hash)
        -- Get voxel face vector
        local face_vec = FACE_VECTORS[face]
        if face_vec then
          -- Compute position of the node in front (target)
          local target_pos = {
            x = pos.x + face_vec.x,
            y = pos.y + face_vec.y,
            z = pos.z + face_vec.z
          }
          -- Read node at target position
          local node = minetest.get_node_or_nil(target_pos)
          if node and is_ore_node(node.name) then
            -- Remove the node and spawn item
            minetest.remove_node(target_pos)
            spawn_ore_item(target_pos, node.name)
            -- Decrease MINE_TOOL port's hardness budget
            local hardness = state.hardness or 1
            local used = math.min(hardness, torque * dt)
            state.hardness = hardness - used
            -- Write back state
            ports_api.write(port_id, "hardness", state.hardness)
            dirty = true
          end
        end
      end
    end
  end

  return dirty
end

return mining
```

