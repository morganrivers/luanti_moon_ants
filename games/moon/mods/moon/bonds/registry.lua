-- seems like the idea here is to bond stuff together over the avilable faces.
-- basically all created bonds are looped over and indexed with a hash key for some reason

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

local function make_bond_key(pos_hashA, faceA, pos_hashB, faceB)
  if pos_hashA < pos_hashB or (pos_hashA == pos_hashB and faceA <= faceB) then
    return ("%08x_%d_%08x_%d"):format(pos_hashA, faceA, pos_hashB, faceB)
  else
    return ("%08x_%d_%08x_%d"):format(pos_hashB, faceB, pos_hashA, faceA)
  end
end

-- Insert or replace a bond record
function registry.add(pos_hashA, faceA, pos_hashB, faceB, bond_record)
  local key = make_bond_key(pos_hashA, faceA, pos_hashB, faceB)
  print("")
  print("ADDING A BOND RECORD WITH VALUE")
  print(bond_record)
  print(bond_record["omega_rpm"])
  print(bond_record.omega_rpm)
  print(bond_record["torque_Nm"])
  print(bond_record.torque_Nm)
  -- SHAFT: omega_rpm", "torque_Nm"
  print("")
  bond_map[key] = bond_record
end

-- Remove a bond record
function registry.delete(pos_hashA, faceA, pos_hashB, faceB)
  local key = make_bond_key(pos_hashA, faceA, pos_hashB, faceB)
  bond_map[key] = nil
end

function registry.clear()
  registry._store = {}
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
    -- print("")
    -- print("a")
    -- print(a)
    local fa = tonumber(parts[2])
    -- print("fa")
    -- print(fa)
    local b = tonumber(parts[3], 16)
    -- print("b")
    -- print(b)
    local fb = tonumber(parts[4])
    -- print("fb")
    -- print(fb)
    
    if (a == pos_hashA and fa == faceA) or (b == pos_hashA and fb == faceA) then
      return v
    end
  end
  return nil
end

-- Iterate all bonds attached to a voxel
-- basically, goes over the records, tries to find them
function registry.pairs_for_voxel(pos_hash)
  print("")
  print("running pairs for voxel")
  local result = {}
  for k, rec in pairs(bond_map) do
    local parts = {}
    for part in k:gmatch("[^_]+") do
      table.insert(parts, part)
      -- print("parts, part")
      -- print(parts)
      -- print(part)
      -- print()
    end
    
    local a = tonumber(parts[1], 16)
    local b = tonumber(parts[3], 16)
    
    if a == pos_hash or b == pos_hash then
      table.insert(result, rec)
    -- print("")
    -- print("RUNNING ALL PARES")
    -- print("result, rec")
    -- print(result)
    -- print("finished running pairs")
    -- print("")
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

