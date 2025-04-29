-- solvers/material_flow.lua
-- Moves item entities via gravity pipes and MATERIAL_IO ports; handles powder deposition

dofile(minetest.get_modpath("moon") .. "/constants.lua")
dofile(minetest.get_modpath("moon") .. "/util.lua")
dofile(minetest.get_modpath("moon") .. "/ports/types.lua")
dofile(minetest.get_modpath("moon") .. "/ports/registry.lua")
dofile(minetest.get_modpath("moon") .. "/ports/api.lua")
dofile(minetest.get_modpath("moon") .. "/voxels/metadata.lua")
dofile(minetest.get_modpath("moon") .. "/materials/registry.lua")
local moon           = rawget(_G, "moon") or {}

local DIRS = util.DIRS or {
  { x =  0, y = -1, z =  0 }, -- down
  { x =  0, y =  1, z =  0 }, -- up
  { x =  1, y =  0, z =  0 }, -- east
  { x = -1, y =  0, z =  0 }, -- west
  { x =  0, y =  0, z =  1 }, -- south
  { x =  0, y =  0, z = -1 }, -- north
}

local DOWN_IDX = 1

-- Helper: check if a voxel at pos is empty (air or replaceable)
local function is_empty_voxel(pos)
  local node = minetest.get_node_or_nil(pos)
  if not node then return false end
  return node.name == "air" or node.name == "ignore"
end

-- Helper: get the next position in the given direction
local function step_vec(pos, dir)
  return {x=pos.x+dir.x, y=pos.y+dir.y, z=pos.z+dir.z}
end

-- Helper: test if a voxel is a conveyor (FLUID flag + SLIDER bond)
local function is_conveyor(pos)
  local meta = voxels_meta.read(pos)
  if not meta then return false end
  if not util.has_flag(meta.flags, moon.MATERIAL.FLUID) then return false end
  -- Check for SLIDER bond on this voxel (any face)
  for face = 1, 6 do
    local bonds = moon.bonds.pairs_for_voxel(util.hash(pos))
    for _, bond in pairs(bonds) do
      if bond.type == moon.BOND.SLIDER then
        return true
      end
    end
  end
  return false
end

-- Helper: try move an item from one MATERIAL_IO port to neighbor if possible
local function move_item_through_port(port_id, port, port_map)
  local pos = util.unhash(port.pos_hash)
  local face = port.face
  local dir = util.FACE_TO_DIR[face] or DIRS[face]
  local dst_pos = step_vec(pos, dir)
  local dst_hash = util.hash(dst_pos)
  -- Find if neighbor has a MATERIAL_IO port facing back
  for _, neighbor_port_id in ipairs(ports_registry.ports_for_voxel(dst_hash) or {}) do
    local nport = ports_registry.lookup(neighbor_port_id)
    if nport and nport.class == moon.PORT.MATERIAL_IO then
      -- Check queue space in neighbor
      if #nport.state.queue < constants.MATERIAL_IO_QUEUE_MAX then
        -- Move item
        local item = table.remove(port.state.queue, 1)
        if item then
          table.insert(nport.state.queue, item)
          ports_api.write(port_id, "queue", port.state.queue)
          ports_api.write(neighbor_port_id, "queue", nport.state.queue)
          -- Mark both ports dirty
          return true
        end
      end
    end
  end
  return false
end

-- Helper: move items by gravity
local function gravity_move_item(port_id, port)
  local pos = util.unhash(port.pos_hash)
  local down = DIRS[DOWN_IDX]
  local below = step_vec(pos, down)
  -- Only move if there's a MATERIAL_IO port below
  local below_hash = util.hash(below)
  for _, neighbor_port_id in ipairs(ports_registry.ports_for_voxel(below_hash) or {}) do
    local nport = ports_registry.lookup(neighbor_port_id)
    if nport and nport.class == moon.PORT.MATERIAL_IO then
      if #nport.state.queue < constants.MATERIAL_IO_QUEUE_MAX then
        local item = table.remove(port.state.queue, 1)
        if item then
          table.insert(nport.state.queue, item)
          ports_api.write(port_id, "queue", port.state.queue)
          ports_api.write(neighbor_port_id, "queue", nport.state.queue)
          return true
        end
      end
    end
  end
  return false
end

-- Helper: move items sideways (conveyor)
local function sideways_move_item(port_id, port)
  local pos = util.unhash(port.pos_hash)
  local moved = false
  -- Try all horizontal directions except down
  for i = 3, 6 do
    local dir = DIRS[i]
    local side_pos = step_vec(pos, dir)
    if is_conveyor(side_pos) then
      local side_hash = util.hash(side_pos)
      for _, neighbor_port_id in ipairs(ports_registry.ports_for_voxel(side_hash) or {}) do
        local nport = ports_registry.lookup(neighbor_port_id)
        if nport and nport.class == moon.PORT.MATERIAL_IO then
          if #nport.state.queue < constants.MATERIAL_IO_QUEUE_MAX then
            local item = table.remove(port.state.queue, 1)
            if item then
              table.insert(nport.state.queue, item)
              ports_api.write(port_id, "queue", port.state.queue)
              ports_api.write(neighbor_port_id, "queue", nport.state.queue)
              moved = true
              break
            end
          end
        end
      end
      if moved then break end
    end
  end
  return moved
end

-- Helper: handle powder spawn request
local function spawn_powder_from_port(port_id, port)
  local cmd = port.state.spawn_powder
  if not cmd then return false end
  local pos = util.unhash(port.pos_hash)
  local face = port.face
  local dir = util.FACE_TO_DIR[face] or DIRS[face]
  local tgt_pos = step_vec(pos, dir)
  if is_empty_voxel(tgt_pos) then
    -- Place FLUID voxel of material
    local mat_id = cmd.material_id
    local meta = {
      flags = moon.MATERIAL.FLUID,
      material_id = mat_id,
      port_id = 0,
      temperature = materials_reg.get(mat_id).baseline_T or 300,
    }
    minetest.set_node(tgt_pos, {name = "moon:fluid_" .. mat_id})
    voxels_meta.write(tgt_pos, meta)
    port.state.spawn_powder = nil
    ports_api.write(port_id, "spawn_powder", nil)
    return true
  end
  return false
end

-- Main solver step function
local function step(island, dt)
  -- Track if any items moved or powder spawned
  local dirty = false
  -- Build port_id → port map for this island's ports
  local port_map = {}
  for port_id in pairs(island.ports) do
    local port = ports_registry.lookup(port_id)
    if port and port.class == moon.PORT.MATERIAL_IO then
      port_map[port_id] = port
    end
  end

  -- 1. Handle powder spawn requests first (so new items can enter queues below)
  for port_id, port in pairs(port_map) do
    if port.state.spawn_powder then
      if spawn_powder_from_port(port_id, port) then
        dirty = true
      end
    end
  end

  -- 2. Move items by gravity first
  for port_id, port in pairs(port_map) do
    if #port.state.queue > 0 then
      if gravity_move_item(port_id, port) then
        dirty = true
      end
    end
  end

  -- 3. Move items sideways along conveyors
  for port_id, port in pairs(port_map) do
    if #port.state.queue > 0 then
      if sideways_move_item(port_id, port) then
        dirty = true
      end
    end
  end

  -- 4. Try direct port-to-port transfers (same level)
  for port_id, port in pairs(port_map) do
    if #port.state.queue > 0 then
      if move_item_through_port(port_id, port, port_map) then
        dirty = true
      end
    end
  end

  return dirty
end

return {
  step = step,
}
