-- islands/detector.lua
-- Flood-fill routine to group connected active voxels into simulation islands

-- Use global objects instead of loading individual modules
-- constants, util, voxels, bonds, ports are all global

local ISLAND_MAX_VOXELS = constants.ISLAND_MAX_VOXELS or 4096

local detector = {}

-- Weak-valued table: drops islands if all voxels are unloaded
local island_store = setmetatable({}, {__mode = "v"})

local next_island_id = 1

-- Returns: set {pos_hash=true, ...}, set {bond_key=true, ...}, set {port_id=true, ...}
local function flood_fill(seed_pos_hash, seen_voxels, seen_bonds, seen_ports)
  local queue = {seed_pos_hash}
  local q_head, q_tail = 1, 1

  while q_head <= q_tail do
    local pos_hash = queue[q_head]
    q_head = q_head + 1

    if not pos_hash then
      -- Skip nil entries
    elseif seen_voxels[pos_hash] then
      -- Skip if already seen
    else
      seen_voxels[pos_hash] = true

      -- Check for ports on this voxel
      for port_id in ports.registry.ports_for_voxel(pos_hash) do
        seen_ports[port_id] = true
      end

      -- For every bond touching this voxel
      for bond_key, bond in bonds.registry.pairs_for_voxel(pos_hash) do
        seen_bonds[bond_key] = true

        local other_hash = bond.a.pos_hash == pos_hash and bond.b.pos_hash or bond.a.pos_hash
        if other_hash and not seen_voxels[other_hash] then
          q_tail = q_tail + 1
          queue[q_tail] = other_hash
        end
      end

      -- Stop if we hit max (count table entries manually)
      local voxel_count = 0
      for _ in pairs(seen_voxels) do voxel_count = voxel_count + 1 end
      if voxel_count >= ISLAND_MAX_VOXELS then
        break
      end
    end
  end

  return seen_voxels, seen_bonds, seen_ports
end

-- Recomputes all islands from full port list (tick 0)
function detector.scan_all()
  local seeds = {}
  for port_id, port in pairs(ports.registry._all_ports()) do
    seeds[port.pos_hash] = true
  end

  -- Mark all voxels as not yet assigned
  local assigned = {}

  for seed_hash, _ in pairs(seeds) do
    if not assigned[seed_hash] then
      local voxels, bonds, ports = {}, {}, {}
      flood_fill(seed_hash, voxels, bonds, ports)
      -- minetest.log("action", ("[detector] refresh island_id=%d  voxels=%d  bonds=%d  ports=%d")
      --   :format(island_id, util.table_count(voxels), util.table_count(bonds), util.table_count(ports)))

      -- for h, _ in pairs(voxels) do
      --   minetest.log("action", ("[detector]   + voxel %08x"):format(h))
      -- end

      -- minetest.log("action", ("[detector] scan island_id=%d  voxels=%d  bonds=%d  ports=%d")
      --   :format(island_id, util.table_count(voxels), util.table_count(bonds), util.table_count(ports)))

      -- for h, _ in pairs(voxels) do
      --   minetest.log("action", ("[detector]   + voxel %08x"):format(h))
      -- end

      -- Assign all voxels to this island
      local island_id = next_island_id
      next_island_id = next_island_id + 1

      
      -- debug: summary
      minetest.log("action", ("[detector] island %d  voxels=%d  bonds=%d  ports=%d")
        :format(island_id,
                util.table_count(voxels),
                util.table_count(bonds),
                util.table_count(ports)))

      -- debug: list every voxel
      for h in pairs(voxels) do
        minetest.log("action", ("[detector]   +voxel %08x"):format(h))
      end

      for h, _ in pairs(voxels) do assigned[h] = island_id end
      island_store[island_id] = {
        id = island_id,
        voxels = voxels,
        bonds = bonds,
        ports = ports,
        dirty = true,
      }
    end
  end

  return island_store
end

-- After a port state, bond, or reaction triggers at pos_hash, recompute island containing it
function detector.refresh_from_seed(seed_pos_hash)
  -- Remove any old island containing this voxel
  for id, island in pairs(island_store) do
    if island.voxels and island.voxels[seed_pos_hash] then
      island_store[id] = nil
    end
  end

  local voxels, bonds, ports = {}, {}, {}
  flood_fill(seed_pos_hash, voxels, bonds, ports)
  if util.table_count(voxels) == 0 then return nil end

  local island_id = next_island_id
  next_island_id = next_island_id + 1

  island_store[island_id] = {
    id = island_id,
    voxels = voxels,
    bonds = bonds,
    ports = ports,
    dirty = true,
  }

  return island_id
end

-- Returns the current table of all active islands (id → island data)
function detector.active_islands()
  return island_store
end

return detector

