local util = require("util")
local registry = require("bonds/registry")
local types = require("bonds/types")

local api = {}

-- Helper: checks if two faces are opposite (0-5: +X,-X,+Y,-Y,+Z,-Z)
local function faces_are_opposite(faceA, faceB)
  return (faceA // 2 == faceB // 2) and ((faceA % 2) ~= (faceB % 2))
end

-- Helper: checks if two positions are adjacent along a given face direction
local function are_adjacent(posA, faceA, posB, faceB)
  local dirs = util.axis_dirs
  local dirA = dirs[faceA + 1]
  local dirB = dirs[faceB + 1]
  -- posB must be posA + dirA, and posA must be posB + dirB (i.e. inverse)
  return
    posB.x == posA.x + dirA[1] and
    posB.y == posA.y + dirA[2] and
    posB.z == posA.z + dirA[3] and
    posA.x == posB.x + dirB[1] and
    posA.y == posB.y + dirB[2] and
    posA.z == posB.z + dirB[3]
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

-- Create a bond between two voxel faces; fails if not adjacent, not opposite, or bond exists
function api.create(posA, faceA, posB, faceB, bond_type, state_tbl)
  if not faces_are_opposite(faceA, faceB) then
    return nil, "Faces are not opposite"
  end
  if not are_adjacent(posA, faceA, posB, faceB) then
    return nil, "Voxels are not adjacent"
  end
  local kA, fA, kB, fB = make_canonical_key(posA, faceA, posB, faceB)
  if registry.get(posA, faceA) or registry.get(posB, faceB) then
    return nil, "Bond already exists"
  end
  local bond_type_rec = types[bond_type]
  if not bond_type_rec then
    return nil, "Unknown bond type"
  end
  -- Shallow copy state_tbl or type default
  local state = {}
  if bond_type_rec.state_keys then
    for _, key in ipairs(bond_type_rec.state_keys) do
      state[key] = state_tbl and state_tbl[key] or bond_type_rec.defaults and bond_type_rec.defaults[key] or nil
    end
  end
  local record = {
    type = bond_type,
    state = state,
    posA_hash = util.hash(posA),
    faceA = faceA,
    posB_hash = util.hash(posB),
    faceB = faceB,
  }
  registry.insert(kA, fA, kB, fB, record)
  return record
end

-- Breaks (removes) the bond at posA,faceA (and its dual)
function api.break_bond(posA, faceA)
  local record = registry.get(posA, faceA)
  if not record then return false end
  registry.remove(posA, faceA)
  registry.remove({x=record.posB_hash}, record.faceB) -- registry.remove is safe to call on non-existent
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
  return registry.get(pos, face)
end

-- Expose: iterate all bonds touching a voxel
function api.pairs_for_voxel(pos)
  return registry.pairs_for_voxel(util.hash(pos))
end

return api
