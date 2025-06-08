

local util = dofile(minetest.get_modpath("moon") .. "/util.lua")
local registry = dofile(minetest.get_modpath("moon") .. "/bonds/registry.lua")
local types = dofile(minetest.get_modpath("moon") .. "/bonds/types.lua")

local api = {}

-- Helper: checks if two faces are opposite (0-5: +X,-X,+Y,-Y,+Z,-Z)
local function faces_are_opposite(faceA, faceB)
  return (math.floor(faceA / 2) == math.floor(faceB / 2)) and ((faceA % 2) ~= (faceB % 2))
end

-- Helper: checks if two positions are adjacent along a given face direction
local function are_adjacent(posA, faceA, posB, faceB)
  local dirs = util.axis_dirs
  local dirA = dirs[faceA]
  local dirB = dirs[faceB]
  print("")
  print("Are adjacent: dirs")
  print("Dirs face A x y")
  print(dirA.x)
  print(dirA.y)
  print("Dirs face B")
  print(dirB.x)
  print(dirB.y)
  print("")

  -- posB must be posA + dirA, and posA must be posB + dirB (i.e. inverse)
  return
    posB.x == posA.x + dirA.x and
    posB.y == posA.y + dirA.y and
    posB.z == posA.z + dirA.z and
    posA.x == posB.x + dirB.x and
    posA.y == posB.y + dirB.y and
    posA.z == posB.z + dirB.z
end

-- Helper: returns canonical key ordering for (posA,faceA,posB,faceB)
local function make_canonical_key(posA, faceA, posB, faceB)
  local hashA = util.hash(posA)
  local hashB = util.hash(posB)
  if hashA < hashB or (hashA == hashB and faceA < faceB) then
    return hashA, faceA, hashB, faceB
  else
    return hashB, faceB, hashA, faceA
  end
end


function api.create(posA, faceA, posB, faceB, bond_type, state_tbl)
  if not faces_are_opposite(faceA, faceB) then
    print("ERROR: cannot create bond: Faces are not opposite")
    return false, "Faces are not opposite"
  end
  if not are_adjacent(posA, faceA, posB, faceB) then
    print("ERROR: cannot create bond: Voxels are not adjacent")
    return false, "Voxels are not adjacent"
  end
  print("1")
  local kA, fA, kB, fB = make_canonical_key(posA, faceA, posB, faceB)
  if registry.get(util.hash(posA), faceA) or
     registry.get(util.hash(posB), faceB) then
    print("ERROR: cannot create bond: Bond already exists")
    return false, "Bond already exists"
  end
  if not types.fields[bond_type] then
    print("ERROR: cannot create bond: Unknown bond type")
    return false, "Unknown bond type"
  end
  print("2")

  -- Shallow copy state_tbl or type default
  local state = {}
  for _, key in ipairs(types.fields[bond_type]) do
    state[key] = state_tbl and state_tbl[key] or types.defaults[bond_type] and types.defaults[bond_type][key] or nil
  end

  local record = {
    type  = bond_type,
    state = state,
    -- canonical “a” / “b” endpoints (mechanical solver expects these)
    a = { pos_hash = util.hash(posA), face = faceA },
    b = { pos_hash = util.hash(posB), face = faceB },
  }
  -- print("")
  -- print("CREATE record")
  -- print(record)
  -- print("record.a.pos_hash")
  -- print(record.a.pos_hash)
  -- print("record.b.pos_hash")
  -- print(record.b.pos_hash)
  -- print("record.a.face")
  -- print(record.a.face)
  -- print("record.b.face")
  -- print(record.b.face)
  -- print("record.type")
  -- print(record.type)
  -- print("record.state")
  -- print(record.state)
  -- print("")
  -- surface frequently-used state fields at top level (omega_rpm…)
  for k, v in pairs(state) do record[k] = v end

  registry.add(record.a.pos_hash, record.a.face,
               record.b.pos_hash, record.b.face,
               record)

  -- Trigger island detection when bond is created
  if moon and moon.islands and moon.islands.detector then
    print("[moon] Bond created, detecting new islands...")
    local all_islands = moon.islands.detector.scan_all()
    print("[moon] scan_all returned " .. #all_islands .. " islands")
    
    -- Debug: log details about first island
    if #all_islands > 0 then
      local island = all_islands[1]
      local voxel_count = 0
      for _ in pairs(island.voxels or {}) do voxel_count = voxel_count + 1 end
      print("[moon] First island has " .. voxel_count .. " voxels")
    end
    
    if moon.islands.queue then
      local now = minetest.get_gametime()
      for _, island in ipairs(all_islands) do
        -- Schedule for immediate processing (current time - small offset)
        moon.islands.queue.push_or_update(island, now - 0.001)
      end
      print("[moon] Queued " .. #all_islands .. " islands for processing at time " .. (now - 0.001))
    else
      print("[moon] WARNING: queue not available")
    end
  else
    print("[moon] WARNING: islands/detector not available")
  end

  return true, record
end


-- Breaks (removes) the bond at posA,faceA (and its dual)
function api.break_bond(posA, faceA)
  local record = registry.get(util.hash(posA), faceA)
  print()
  print("break_bond")
  print("record.a.pos_hash")
  print(record.a.pos_hash)
  print("record.a.face")
  print(record.a.face)
  print("record.b.pos_hash")
  print(record.b.pos_hash)
  print("record.b.face")
  print(record.b.face)
  if not record then return false end
  -- registry.delete(record.posA_hash, record.faceA, record.posB_hash, record.faceB)
  registry.delete(record.a.pos_hash, record.a.face,
                  record.b.pos_hash, record.b.face)
  return true
end

-- Set a state field of a bond record and return new value
function api.set_state(record, key, value)
  if record and record.state then
    record.state[key] = value
    return value
  end
  return nil
end

-- Expose: get bond record at a voxel-face
function api.get(pos, face)
  return registry.get(util.hash(pos), face)
end

-- Expose: iterate all bonds touching a voxel
function api.pairs_for_voxel(pos)
  if type(pos) == "number" then
    return registry.pairs_for_voxel(pos) -- Already a hash
  else
    return registry.pairs_for_voxel(util.hash(pos))
  end
end

return api

