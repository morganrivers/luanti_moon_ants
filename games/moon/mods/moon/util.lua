-- util.lua
-- Pure helper functions (vector math, object pools, bit ops) with zero dependencies on domain logic
local bit = dofile(minetest.get_modpath("moon") .. "/lib/bit.lua")

local existing = rawget(_G, "__moon_util")
if existing then
  return existing
end

util = {}
_G.__moon_util = util

-- ================================
-- Vector3 integer math
-- ================================

-- Adds two integer vector3 tables {x=,y=,z=}
function util.vec3_add(a, b)
  return { x = a.x + b.x, y = a.y + b.y, z = a.z + b.z }
end

-- Subtracts vector b from vector a
function util.vec3_sub(a, b)
  return { x = a.x - b.x, y = a.y - b.y, z = a.z - b.z }
end

-- In-place add: out = a + b (out is an existing table)
function util.vec3_add_inplace(out, a, b)
  out.x = a.x + b.x
  out.y = a.y + b.y
  out.z = a.z + b.z
  return out
end

-- In-place sub: out = a - b
function util.vec3_sub_inplace(out, a, b)
  out.x = a.x - b.x
  out.y = a.y - b.y
  out.z = a.z - b.z
  return out
end

-- Returns true if two integer vec3 tables are equal
function util.vec3_eq(a, b)
  return a.x == b.x and a.y == b.y and a.z == b.z
end

-- -- Fast 32-bit FNV-1a hash for integer coordinates (x, y, z)
-- -- Returns unsigned int
-- function util.vec3_hash(pos)
--   local x, y, z = pos.x, pos.y, pos.z
--   local h = 2166136261
--   local function fnv_mix(v)
--     h = h ~ (v & 0xFF); h = (h * 16777619) & 0xFFFFFFFF
--     h = h ~ ((v >> 8) & 0xFF); h = (h * 16777619) & 0xFFFFFFFF
--     h = h ~ ((v >> 16) & 0xFF); h = (h * 16777619) & 0xFFFFFFFF
--     h = h ~ ((v >> 24) & 0xFF); h = (h * 16777619) & 0xFFFFFFFF
--   end
--   fnv_mix(x)
--   fnv_mix(y)
--   fnv_mix(z)
--   return h
-- end

-- Same, but for explicit integers (x, y, z)
-- function util.hash_xyz(x, y, z)
--   local h = 2166136261
--   local function fnv_mix(v)
--     h = h ~ (v & 0xFF); h = (h * 16777619) & 0xFFFFFFFF
--     h = h ~ ((v >> 8) & 0xFF); h = (h * 16777619) & 0xFFFFFFFF
--     h = h ~ ((v >> 16) & 0xFF); h = (h * 16777619) & 0xFFFFFFFF
--     h = h ~ ((v >> 24) & 0xFF); h = (h * 16777619) & 0xFFFFFFFF
--   end
--   fnv_mix(x)
--   fnv_mix(y)
--   fnv_mix(z)
--   return h
-- end

-- ================================
-- Axis and face helpers
-- ================================

-- 6 axis directions, Minetest order: {+X,-X,+Y,-Y,+Z,-Z}
-- util.axis_dirs = {
--   { x= 1, y= 0, z= 0 },  -- +X
--   { x=-1, y= 0, z= 0 },  -- -X
--   { x= 0, y= 1, z= 0 },  -- +Y
--   { x= 0, y=-1, z= 0 },  -- -Y
--   { x= 0, y= 0, z= 1 },  -- +Z
--   { x= 0, y= 0, z=-1 },  -- -Z
-- }

-- util.lua  – overwrite the table
util.axis_dirs = {
  [0] = {x=-1, y= 0, z= 0}, -- -X
  [1] = {x= 1, y= 0, z= 0}, -- +X
  [2] = {x= 0, y=-1, z= 0}, -- -Y
  [3] = {x= 0, y= 1, z= 0}, -- +Y
  [4] = {x= 0, y= 0, z=-1}, -- -Z
  [5] = {x= 0, y= 0, z= 1}, -- +Z
}

-- Returns the opposite face index (1..6)
-- function util.opposite_face(face)
--   return ((face - 1) ~ 1) + 1
-- end

-- Given a face index (1..6), returns {x, y, z} direction
function util.face_dir(face)
  return util.AXIS6[face]
end

-- ================================
-- Bitfield helpers
-- ================================

-- Returns true if the given mask bit is set in word (word, flag_bit)
function util.has_flag(word, flag_bit)
  return bit.band(word, flag_bit) ~= 0 --not (word and flag_bit == 0) -- = 0 -- DMR changed from   return (word & flag_bit) ~= 0
end

-- Sets a flag bit in word (returns new word)
function util.set_flag(word, flag_bit)
  return bit.bor(word, flag_bit)
end

-- Clears a flag bit in word (returns new word)
function util.clear_flag(word, flag_bit)
  return bit.band(word, (not flag_bit))
end

-- ================================
-- Tiny object pools (freelists)
-- ================================

-- Create a pool of tables (all same shape). When free, tables are chained by ._next.
function util.make_pool(new_fn)
  local pool = { _free = nil }
  -- Allocates new or reuses from pool
  function pool:acquire()
    local t = self._free
    if t then
      self._free = t._next
      t._next = nil
      return t
    else
      return new_fn()
    end
  end
  -- Returns t to pool
  function pool:release(t)
    for k in pairs(t) do  -- clear all fields
      t[k] = nil
    end
    t._next = self._free
    self._free = t
  end
  return pool
end

-------------------------------------------------
-- util.lua  (add **below** the PRIME constants)
-------------------------------------------------
local PRIME1, PRIME2, PRIME3 = 73856093, 19349663, 83492791

-- ------------------------------------------------------------------
-- Hash  ➜ 32-bit  +  reverse lookup table so we can un-hash later
-- ------------------------------------------------------------------
local _reverse_hash = {}         -- weak-valued keeps memory use low
setmetatable(_reverse_hash, { __mode = "v" })

--- forward hash (unchanged, but remember the position we saw)
function util.hash(pos)
  local h = (pos.x * PRIME1 + pos.y * PRIME2 + pos.z * PRIME3) % 0x100000000
  _reverse_hash[h] = { x = pos.x, y = pos.y, z = pos.z } -- store *copy*
  return h
end

--- **new** – turn the 32-bit key back into a {x,y,z} table.
--     · Returns *nil* if we never saw that hash before.
function util.unhash3(h)
  return _reverse_hash[h]
end

-- counts *all* keys in a table (array or hash)
function util.table_count(t)
  local n = 0
  for _ in pairs(t) do n = n + 1 end
  return n
end

return util

