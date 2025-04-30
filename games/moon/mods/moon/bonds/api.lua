

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

-- -- Create a bond between two voxel faces; fails if not adjacent, not opposite, or bond exists
-- function api.create(posA, faceA, posB, faceB, bond_type, state_tbl)
--   if not faces_are_opposite(faceA, faceB) then
--     return nil, "Faces are not opposite"
--   end
--   if not are_adjacent(posA, faceA, posB, faceB) then
--     return nil, "Voxels are not adjacent"
--   end
--   local kA, fA, kB, fB = make_canonical_key(posA, faceA, posB, faceB)
--   if registry.get(posA, faceA) or registry.get(posB, faceB) then
--     return nil, "Bond already exists"
--   end
--   print("types")
--   print(types)
--   if not types.fields[bond_type] then
--     return nil, "Unknown bond type"
--   end

--   -- local bond_type_rec = types[bond_type]
--   -- if not bond_type_rec then
--   --   return nil, "Unknown bond type"
--   -- end
--   -- Shallow copy state_tbl or type default
--   local state = {}
--   if bond_type_rec.state_keys then
--     for _, key in ipairs(bond_type_rec.state_keys) do
--       state[key] = state_tbl and state_tbl[key] or bond_type_rec.defaults and bond_type_rec.defaults[key] or nil
--     end
--   end
--   local record = {
--     type = bond_type,
--     state = state,
--     posA_hash = util.hash(posA),
--     faceA = faceA,
--     posB_hash = util.hash(posB),
--     faceB = faceB,
--   }
--   registry.insert(kA, fA, kB, fB, record)
--   return record
-- end

function api.create(posA, faceA, posB, faceB, bond_type, state_tbl)
  if not faces_are_opposite(faceA, faceB) then
    return false, "Faces are not opposite"
  end
  if not are_adjacent(posA, faceA, posB, faceB) then
    return false, "Voxels are not adjacent"
  end
  local kA, fA, kB, fB = make_canonical_key(posA, faceA, posB, faceB)
  if registry.get(posA, faceA) or registry.get(posB, faceB) then
--  if api.get(posA, faceA) or api.get(posB, faceB) then
    return false, "Bond already exists"
  end
  if not types.fields[bond_type] then
    return false, "Unknown bond type"
  end

  -- Shallow copy state_tbl or type default
  local state = {}
  for _, key in ipairs(types.fields[bond_type]) do
    state[key] = state_tbl and state_tbl[key] or types.defaults[bond_type] and types.defaults[bond_type][key] or nil
  end

  print("util.hash(posA)")
  print(util.hash(posA))
  local record = {
    type = bond_type,
    state = state,
    posA_hash = util.hash(posA),
    faceA = faceA,
    posB_hash = util.hash(posB),
    faceB = faceB,
  }
  registry.set(record.posA_hash, record.faceA, record.posB_hash, record.faceB, record)
  -- registry.insert(kA, fA, kB, fB, record)
  return true, record
end


-- Breaks (removes) the bond at posA,faceA (and its dual)
function api.break_bond(posA, faceA)
  local record = registry.get(util.hash(posA), faceA)
  if not record then return false end
  registry.delete(record.posA_hash, record.faceA, record.posB_hash, record.faceB)
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
  return registry.pairs_for_voxel(util.hash(pos))
end

return api

