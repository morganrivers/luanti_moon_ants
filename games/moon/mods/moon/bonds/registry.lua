dofile(minetest.get_modpath("moon") .. "/util.lua")
local types = dofile(minetest.get_modpath("moon") .. "/bonds/types.lua")

-- Return the already-loaded registry if it exists
-- if rawget(_G, "__moon_bond_registry") then
--   return _G.__moon_bond_registry
-- end


local existing = rawget(_G, "__moon_bond_registry")
if existing then return existing end

local bond_map  = {}
local registry  = { _bonds = bond_map }   -- _bonds lets the test-suite wipe state

-- expose it globally so the next dofile() sees the same table
_G.__moon_bond_registry = registry
-- registry = {}

-- Internal bond storage:
-- Key: pos_hashA<<7|faceA  ..  pos_hashB<<7|faceB (smaller first for symmetry)
-- local bond_map = {}

-- -- Helper: canonicalize (pos_hashA, faceA, pos_hashB, faceB) to symmetric key
-- local function make_bond_key(pos_hashA, faceA, pos_hashB, faceB)
--   print("pos_hashA")
--   print("faceA")
--   print(pos_hashA)
--   print(faceA)
--   -- guarantee (smaller,face),(larger,face) order for symmetry
--   if pos_hashA < pos_hashB or (pos_hashA == pos_hashB and faceA <= faceB) then
--     return string.pack(">I4B1I4B1", pos_hashA, faceA, pos_hashB, faceB)
--   else
--     return string.pack(">I4B1I4B1", pos_hashB, faceB, pos_hashA, faceA)
--   end
-- end

local function make_bond_key(pos_hashA, faceA, pos_hashB, faceB)
  if pos_hashA < pos_hashB or (pos_hashA == pos_hashB and faceA <= faceB) then
    return ("%08x_%d_%08x_%d"):format(pos_hashA, faceA, pos_hashB, faceB)
  else
    return ("%08x_%d_%08x_%d"):format(pos_hashB, faceB, pos_hashA, faceA)
  end
end

-- Insert or replace a bond record
function registry.set(pos_hashA, faceA, pos_hashB, faceB, bond_record)
  local key = make_bond_key(pos_hashA, faceA, pos_hashB, faceB)
  bond_map[key] = bond_record
end

-- Remove a bond record
function registry.delete(pos_hashA, faceA, pos_hashB, faceB)
  local key = make_bond_key(pos_hashA, faceA, pos_hashB, faceB)
  bond_map[key] = nil
end

-- Lookup bond by one end
function registry.get(pos_hashA, faceA)
  -- This may match any bond sharing this voxel+face
  -- Iterate all bonds and return the first where this end matches
  for k, v in pairs(bond_map) do
    local parts = {}
    for part in k:gmatch("[^_]+") do
      table.insert(parts, part)
    end
    
    local a = tonumber(parts[1], 16)
    local fa = tonumber(parts[2])
    local b = tonumber(parts[3], 16)
    local fb = tonumber(parts[4])
    
    if (a == pos_hashA and fa == faceA) or (b == pos_hashA and fb == faceA) then
      return v
    end
  end
  return nil
end

-- Iterate all bonds attached to a voxel
function registry.pairs_for_voxel(pos_hash)
  local result = {}
  for k, rec in pairs(bond_map) do
    local parts = {}
    for part in k:gmatch("[^_]+") do
      table.insert(parts, part)
    end
    
    local a = tonumber(parts[1], 16)
    local b = tonumber(parts[3], 16)
    
    if a == pos_hash or b == pos_hash then
      table.insert(result, rec)
    end
  end
  
  local i = 0
  return function()
    i = i + 1
    local rec = result[i]
    if rec then
      return i, rec
    end
  end
end

-- For debugging: iterate all bonds
function registry.pairs()
  return pairs(bond_map)
end

return registry

