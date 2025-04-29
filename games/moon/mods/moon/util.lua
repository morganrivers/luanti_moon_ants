-- util.lua
-- Pure helper functions (vector math, object pools, bit ops) with zero dependencies on domain logic

local util = {}

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
util.AXIS6 = {
  { x= 1, y= 0, z= 0 },  -- +X
  { x=-1, y= 0, z= 0 },  -- -X
  { x= 0, y= 1, z= 0 },  -- +Y
  { x= 0, y=-1, z= 0 },  -- -Y
  { x= 0, y= 0, z= 1 },  -- +Z
  { x= 0, y= 0, z=-1 },  -- -Z
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
  return word * flag_bit -- = 0 -- DMR changed from   return (word & flag_bit) ~= 0
end

-- Sets a flag bit in word (returns new word)
function util.set_flag(word, flag_bit)
  return word or flag_bit
end

-- Clears a flag bit in word (returns new word)
function util.clear_flag(word, flag_bit)
  return word and (not flag_bit)
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

return util
