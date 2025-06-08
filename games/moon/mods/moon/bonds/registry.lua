-- bonds/registry.lua  –  FINAL WORKING VERSION
------------------------------------------------

local util  = dofile(minetest.get_modpath("moon") .. "/util.lua")
local types = dofile(minetest.get_modpath("moon") .. "/bonds/types.lua")

-----------------------------------------
-- Singleton boiler-plate
-----------------------------------------
local existing = rawget(_G, "__moon_bond_registry")
if existing then return existing end

local bond_map        = {}            -- key  → bond_rec   (master table)
local bonds_by_voxel  = {}            -- pos → {face → bond_rec}

local registry = { _bonds = bond_map }   -- for test-suite wipes
_G.__moon_bond_registry = registry

-----------------------------------------
-- Helpers
-----------------------------------------
local function make_bond_key(posA, faceA, posB, faceB)
  if posA < posB or (posA == posB and faceA <= faceB) then
    return ("%08x_%d_%08x_%d"):format(posA, faceA, posB, faceB)
  else
    return ("%08x_%d_%08x_%d"):format(posB, faceB, posA, faceA)
  end
end

local function add_to_voxel_index(pos, face, rec)
  if not bonds_by_voxel[pos] then bonds_by_voxel[pos] = {} end
  bonds_by_voxel[pos][face] = rec
end

local function remove_from_voxel_index(pos, face)
  local t = bonds_by_voxel[pos]
  if t then
    t[face] = nil
    if next(t) == nil then bonds_by_voxel[pos] = nil end
  end
end

-----------------------------------------
-- Public API
-----------------------------------------

-- Insert or replace a bond record
function registry.add(posA, faceA, posB, faceB, rec)
  local key = make_bond_key(posA, faceA, posB, faceB)

  -- master table
  bond_map[key] = rec

  -- per-voxel index
  add_to_voxel_index(posA, faceA, rec)
  add_to_voxel_index(posB, faceB, rec)

  return key
end

-- Remove a bond record
function registry.delete(posA, faceA, posB, faceB)
  local key = make_bond_key(posA, faceA, posB, faceB)
  local rec = bond_map[key]
  if not rec then return false end

  bond_map[key] = nil
  remove_from_voxel_index(posA, faceA)
  remove_from_voxel_index(posB, faceB)
  return true
end

-- Fast wipe for test-suite / reload
function registry.clear()
  for k in pairs(bond_map) do bond_map[k] = nil end
  for k in pairs(bonds_by_voxel) do bonds_by_voxel[k] = nil end
end

-- Lookup the first bond at (pos, face) – unchanged
function registry.get(pos, face)
  for key, rec in pairs(bond_map) do
    local a, fa, b, fb = key:match("(%x+)_(%d)_(%x+)_(%d)")
    if (tonumber(a,16) == pos and tonumber(fa) == face) or
       (tonumber(b,16) == pos and tonumber(fb) == face) then
      return rec
    end
  end
  return nil
end

-- **New**: iterate all bonds attached to a voxel
function registry.pairs_for_voxel(pos)
  local tbl = bonds_by_voxel[pos]
  if not tbl then return function() end end          -- empty iterator
  return pairs(tbl)                                  -- key = face, value = rec
end

-- Iterate every bond in the world (unchanged)
function registry.pairs()
  return pairs(bond_map)
end

return registry

-- -- seems like the idea here is to bond stuff together over the avilable faces.
-- -- basically all created bonds are looped over and indexed with a hash key for some reason
-- local bonds_by_voxel = {}    --  pos_hash -> { [face]=bond_rec, ... }

-- dofile(minetest.get_modpath("moon") .. "/util.lua")
-- local types = dofile(minetest.get_modpath("moon") .. "/bonds/types.lua")

-- -- Return the already-loaded registry if it exists
-- -- if rawget(_G, "__moon_bond_registry") then
-- --   return _G.__moon_bond_registry
-- -- end


-- local existing = rawget(_G, "__moon_bond_registry")
-- if existing then return existing end

-- local bond_map  = {}
-- local registry  = { _bonds = bond_map }   -- _bonds lets the test-suite wipe state

-- -- expose it globally so the next dofile() sees the same table
-- _G.__moon_bond_registry = registry

-- local function make_bond_key(pos_hashA, faceA, pos_hashB, faceB)
--   if pos_hashA < pos_hashB or (pos_hashA == pos_hashB and faceA <= faceB) then
--     return ("%08x_%d_%08x_%d"):format(pos_hashA, faceA, pos_hashB, faceB)
--   else
--     return ("%08x_%d_%08x_%d"):format(pos_hashB, faceB, pos_hashA, faceA)
--   end
-- end

-- -- Insert or replace a bond record
-- function registry.add(pos_hashA, faceA, pos_hashB, faceB, bond_record)
--   local key = make_bond_key(pos_hashA, faceA, pos_hashB, faceB)
--   bonds_by_posface[key_a] = bond_record
--   bonds_by_posface[key_b] = bond_record
--   -- 2. ALSO store in the voxel-level index
--   if not bonds_by_voxel[posA] then bonds_by_voxel[posA] = {} end
--   bonds_by_voxel[posA][faceA] = bond_rec
--   if not bonds_by_voxel[posB] then bonds_by_voxel[posB] = {} end
--   bonds_by_voxel[posB][faceB] = bond_rec

--   print("")
--   print("ADDING A BOND RECORD WITH VALUE")
--   print(bond_record)
--   print(bond_record["omega_rpm"])
--   print(bond_record.omega_rpm)
--   print(bond_record["torque_Nm"])
--   print(bond_record.torque_Nm)
--   -- SHAFT: omega_rpm", "torque_Nm"
--   print("")
--   bond_map[key] = bond_record
-- end

-- -- Remove a bond record
-- function registry.delete(pos_hashA, faceA, pos_hashB, faceB)
--   local key = make_bond_key(pos_hashA, faceA, pos_hashB, faceB)
--   bond_map[key] = nil
-- end

-- function registry.clear()
--   registry._store = {}
-- end

-- -- Lookup bond by one end
-- function registry.get(pos_hashA, faceA)
--   -- This may match any bond sharing this voxel+face
--   -- Iterate all bonds and return the first where this end matches
--   for k, v in pairs(bond_map) do
--     local parts = {}
--     for part in k:gmatch("[^_]+") do
--       table.insert(parts, part)
--     end
    
--     local a = tonumber(parts[1], 16)
--     -- print("")
--     -- print("a")
--     -- print(a)
--     local fa = tonumber(parts[2])
--     -- print("fa")
--     -- print(fa)
--     local b = tonumber(parts[3], 16)
--     -- print("b")
--     -- print(b)
--     local fb = tonumber(parts[4])
--     -- print("fb")
--     -- print(fb)
    
--     if (a == pos_hashA and fa == faceA) or (b == pos_hashA and fb == faceA) then
--       return v
--     end
--   end
--   return nil
-- end

-- -- Iterate all bonds attached to a voxel
-- -- basically, goes over the records, tries to find them
-- function registry.pairs_for_voxel(pos_hash)
--     local by_face = bonds_by_voxel[pos_hash]
--     if not by_face then
--         return function() end            -- empty iterator
--     end
--     local iter, state, var = pairs(by_face)
--     return iter, state, var              -- key = face, value = bond_rec
-- end

-- -- function registry.pairs_for_voxel(pos_hash)
-- --   -- print("")
-- --   -- print("running pairs for voxel")
-- --   local result = {}
-- --   for k, rec in pairs(bond_map) do
-- --     local parts = {}
-- --     for part in k:gmatch("[^_]+") do
-- --       table.insert(parts, part)
-- --       -- print("parts, part")
-- --       -- print(parts)
-- --       -- print(part)
-- --       -- print()
-- --     end
    
-- --     local a = tonumber(parts[1], 16)
-- --     local b = tonumber(parts[3], 16)
    
-- --     if a == pos_hash or b == pos_hash then
-- --       table.insert(result, rec)
-- --     -- print("")
-- --     -- print("RUNNING ALL PARES")
-- --     -- print("result, rec")
-- --     -- print(result)
-- --     -- print("finished running pairs")
-- --     -- print("")
-- --     end
-- --   end
  
-- --   local i = 0
-- --   return function()
-- --     i = i + 1
-- --     local rec = result[i]
-- --     if rec then
-- --       return i, rec
-- --     end
-- --   end
-- -- end

-- -- For debugging: iterate all bonds
-- function registry.pairs()
--   return pairs(bond_map)
-- end

-- return registry

