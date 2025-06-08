-- solvers/mechanical.lua
-- Use shared global modules (avoid separate reverse-hash instances)
local constants       = constants
local util            = util
local bonds_registry  = bonds.registry
local bonds_types     = bonds.types
local ports_registry  = ports.registry
local types           = ports.types
local ports_api       = ports.api
local voxels_metadata = voxels.metadata

-- Caches to minimize table churn
local tmp_chain       = {}
local tmp_visited     = {}
local tmp_bond_stack  = {}

-- Helper: returns the other end of a bond from (pos_hash, face)
local function other_end(bond, pos_hash, face)
  if bond.a.pos_hash == pos_hash and bond.a.face == face then
    return bond.b.pos_hash, bond.b.face
  else
    return bond.a.pos_hash, bond.a.face
  end
end

-- Helper: clears and resets a table
local function clear_table(t)
  for k in pairs(t) do t[k]=nil end
end

-- Find all contiguous SHAFT bonds as a tree, rooted at every unvisited port/voxel
local function collect_shaft_chains(island)
  clear_table(tmp_visited)
  local chains = {}
  for vx_hash in pairs(island.voxels) do
    -- print("vx_hash in island")
    -- print(vx_hash)
    if not tmp_visited[vx_hash] then
      -- Depth-first traversal
      clear_table(tmp_bond_stack)
      tmp_bond_stack[1] = {vx_hash, nil}  -- {pos_hash, incoming_bond}
      local chain = {}
      local chain_set = {}
      while #tmp_bond_stack > 0 do
        local entry = table.remove(tmp_bond_stack)
        local pos_hash = entry[1]
        -- print("pos_hash")
        -- print(pos_hash)
        local in_bond  = entry[2]
        if not tmp_visited[pos_hash] then
          tmp_visited[pos_hash] = true
          chain[#chain+1] = {pos_hash=pos_hash, incoming_bond=in_bond}
          chain_set[pos_hash] = true
          -- print("bonds_registry")
          -- print(bonds_registry)
          -- print("pos_hash")
          -- print(pos_hash)
          -- print("bonds_registry.pairs_for_voxel(pos_hash)")
          -- print(bonds_registry.pairs_for_voxel(pos_hash))

          for _, bond_rec in bonds_registry.pairs_for_voxel(pos_hash) do
            -- print("bond_rec.type")
            -- print(bond_rec.type)
            -- print(bond_rec.a)
            -- print(bond_rec.torque_Nm)
            -- print(bond_rec)
            -- print("bonds_types.SHAFT")
            -- print(bonds_types.SHAFT)
            if bond_rec.type == bonds_types.SHAFT then
              for i, j in pairs(bond_rec) do
              -- print("")
              -- print("bond_rec loop START")
              -- print("i")
              -- print(i)
              -- print("j")
              -- print(j)
              -- print("bond_rec loop END")
              -- print("")
              end
              

              -- CLEARLY THE ISSUE IS THAT I CANT ACCESS POS_HASH FROM THIS RECORD!
              -- THE INFORMATION SIMPLY ISNT THERE

              -- print("")
              -- assert.is_nil(bond_api.get(posA, faceA))
              -- unsure if this means of accessing the pos_hash is valid? What is a, b?
              -- print("bond_rec.b.pos_hash")
              -- print(bond_rec.torque_Nm.pos_hash)
              -- print("")
              -- I dont get it. bond record 
              local nbr_hash = (bond_rec.a.pos_hash == pos_hash) and bond_rec.b.pos_hash or bond_rec.a.pos_hash
              if not chain_set[nbr_hash] then
                tmp_bond_stack[#tmp_bond_stack+1] = {nbr_hash, bond_rec}
              end
            end
          end
        end
      end
      minetest.log("action",
        ("[collect] new chain  len=%d  voxels=%s")
        :format(#chain,
                table.concat((function()
                    local t = {}
                    for i,v in ipairs(chain) do
                        t[#t+1] = string.format("%08x", v.pos_hash)
                    end
                    return t
                end)(), ", ")))

      if #chain > 1 then
        chains[#chains+1] = chain
      end
    end
  end
  return chains
end

-- For each chain, propagate rpm using gear ratios, and set all SHAFT bond state
local function propagate_shaft_rpm(chain, island)
  minetest.log("action", ("[shaft] processing chain with %d entries"):format(#chain))

  local rpm = nil
  local changed = false
  -- First, find if any ACTUATOR port is attached to a voxel in this chain
  for _, entry in ipairs(chain) do

    local vx_hash = entry.pos_hash
    for id in ports_registry.ports_for_voxel(vx_hash) do
      minetest.log("action", ("[shaft] checking voxel %08x for ports"):format(vx_hash))

      local port = ports_registry.lookup(id)
      if port and port.class == types.ACTUATOR then

        minetest.log("action",
          ("[mech] saw ACTUATOR @%08x  id=%d  fields=%s")
          :format(vx_hash, id, minetest.serialize(port.state)))

        if port.state.command then
          minetest.log("action",
      ("[mech] ACTUATOR @%08x id=%d cmd=%s")
      :format(vx_hash, id, tostring(port.state.command)))

          local cmd = port.state.command or 0
          rpm = cmd -- command directly sets target rpm (no inertia)
          minetest.log("action",
            ("[mech] ➜ chain rpm seed set to %d from id=%d"):format(rpm, id))
          break
        end
      end
    end
    if rpm then break end
  end
  if not rpm then
    -- No actuator drive: inherit previous rpm (default 0)
    rpm = 0
  end
  -- Now walk the chain, propagate rpm and set each SHAFT bond state
  for _, entry in ipairs(chain) do
    minetest.log("action", ("[shaft] ➜ propagating rpm starting from: %s"):format(tostring(rpm)))

    if entry.incoming_bond and entry.incoming_bond.type == bonds_types.SHAFT then
      local ratio = entry.incoming_bond.ratio or 1
      rpm = rpm * ratio
      if not (entry.incoming_bond.omega_rpm == rpm) then
        entry.incoming_bond.omega_rpm = rpm
        changed = true
      end
    end
    -- For all SHAFT bonds attached to this voxel, set their omega_rpm
    for _, bond_rec in bonds_registry.pairs_for_voxel(entry.pos_hash) do
      if bond_rec.type == bonds_types.SHAFT then
        minetest.log("action", ("[shaft]   setting omega_rpm=%.2f on bond at %08x"):format(rpm, entry.pos_hash))

        if not (bond_rec.omega_rpm == rpm) then
          bond_rec.omega_rpm = rpm
          changed = true
        end
      end
    end
  end
  return changed
end

-- For each HINGE/SLIDER bond in the island, propagate angle/offset from attached SHAFT rpm
local function propagate_hinge_slider(island)
  local changed = false
  for vx_hash in pairs(island.voxels) do
    for _, bond_rec in bonds_registry.pairs_for_voxel(vx_hash) do
      if bond_rec.type == bonds_types.HINGE then
        -- Find attached SHAFT rpm (search both ends)
        local rpm = 0
        for _, shaft_bond in bonds_registry.pairs_for_voxel(vx_hash) do
          if shaft_bond.type == bonds_types.SHAFT then
            rpm = shaft_bond.omega_rpm or 0
            break
          end
        end
        -- Integrate theta
        local theta = (bond_rec.theta_deg or 0) + rpm * 360/60 * constants.TICK_LENGTH
        theta = theta % 360
        if not (bond_rec.theta_deg == theta) then
          bond_rec.theta_deg = theta
          changed = true
        end
      elseif bond_rec.type == bonds_types.SLIDER then
        -- Find attached SHAFT rpm
        local rpm = 0
        for _, shaft_bond in bonds_registry.pairs_for_voxel(vx_hash) do
          if shaft_bond.type == bonds_types.SHAFT then
            rpm = shaft_bond.omega_rpm or 0
            break
          end
        end
        -- Integrate offset (assume 1mm per rpm per tick for test)
        local offset = (bond_rec.offset_mm or 0) + rpm * 1 * constants.TICK_LENGTH
        if not (bond_rec.offset_mm == offset) then
          bond_rec.offset_mm = offset
          changed = true
        end
      end
    end
  end
  return changed
end

-- For each voxel with printer head/wheel role, update node orientation (facedir) to match mechanical state
local function update_voxel_pose(island)
  local changed = false

  minetest.log("action", ("[moon] update_voxel_pose"))
  minetest.log("action", ("[moon] island.voxels %s!"):format(tostring(island.voxels)))

  for vx_hash in pairs(island.voxels) do
    minetest.log("action", ("[moon] vx_hash in island voxels!"))

    local pos = util.unhash3(vx_hash)
    if pos then
      minetest.log("action", ("[moon] pos exists!"))
      local vmeta = voxels_metadata.read(pos)
      if vmeta and util.has_flag(vmeta.flags, 0x40) then
      minetest.log("action", ("[moon] MECHANICAL_POSE detected..."))
      -- For demo: set facedir based on SHAFT rpm or HINGE theta
      local yaw = 0
      for _, bond_rec in bonds_registry.pairs_for_voxel(vx_hash) do
        minetest.log("action", ("[moon] bond_rec exists..."))
        if bond_rec.type == bonds_types.HINGE then
          yaw = bond_rec.theta_deg or 0
        elseif bond_rec.type == bonds_types.SHAFT then
          yaw = (bond_rec.omega_rpm or 0) * 6 % 360
          minetest.log("action", ("[moon] updated yaw..."))
        end
      end
      -- Quantize to 24 facedir steps (Minetest uses 24)
      local facedir = math.floor(yaw/360 * 24) % 24
      -- Write back (placeholder: actual node update omitted)
      if not (vmeta.facedir == facedir) then
        vmeta.facedir = facedir
        voxels_metadata.write(pos, vmeta)
        changed = true
      end
      end
    end
  end
  return changed
end

-- Detect contact events (e.g. MINE_TOOL impacting terrain)
local function detect_contact_events(island)
  local triggered = false
  -- For each port with MINE_TOOL class, check front neighbor
  for _, port_id in ipairs(island.ports) do
    local port = ports_registry.lookup(port_id)
    if port and port.class == types.MINE_TOOL and (port.state.torque or 0) > 0 then
      local pos = util.unhash3(port.pos_hash)
      if pos then
        local dir = util.face_to_dir(port.face)
        local target = {x=pos.x+dir.x, y=pos.y+dir.y, z=pos.z+dir.z}
        -- Check if node at target is not air (placeholder: actual node lookup omitted)
        -- If real node present, set 'contact' flag in port.state
        -- (The mining solver will consume this)
        if not port.state.contact then
          port.state.contact = true
          triggered = true
        end
      end
    end
  end
  return triggered
end

local function step(island, dt)
  minetest.log("action", ("[moon] island step called"))

  local dirty = false
  -- 1. SHAFT chains: propagate rpm and actuator commands
  minetest.log("propagating shaft chains")
  local chains = collect_shaft_chains(island)
  for _, chain in ipairs(chains) do
    if propagate_shaft_rpm(chain, island) then
      dirty = true
    end
  end
  -- 2. Propagate HINGE/SLIDER positions
  if propagate_hinge_slider(island) then
    dirty = true
  end
  -- 3. Update voxel pose for printer head/wheel
  if update_voxel_pose(island) then
    dirty = true
  end
  -- 4. Detect contact events for mining
  if detect_contact_events(island) then
    dirty = true
  end
  return dirty
end

return {
  step = step
}

