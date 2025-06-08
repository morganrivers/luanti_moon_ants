-- voxels/serialization.lua
-- Encodes/decodes voxel metadata for map-block persistence and version migration

local SCHEMA_VERSION = 1

-- Field layout (byte offsets):
-- 0: version (uint8)
-- 1: flags   (uint8)
-- 2: material_id_len (uint8)
-- 3: material_id (bytes, N)
-- 3+N: port_id (uint64, LE)
-- 11+N: temperature (float32, LE)
-- Total length: 1+1+1+N+8+4 = 15+N bytes

local function encode_u64_le(n)
  -- Returns an 8-byte little-endian string representing unsigned 64-bit integer
  local b = {}
  for i = 1,8 do
    b[i] = string.char(n % 256)
    n = math.floor(n / 256)
  end
  return table.concat(b)
end

local function decode_u64_le(s, offset)
  offset = offset or 1
  local n = 0
  for i = 8,1,-1 do
    n = n * 256 + s:byte(offset + i - 1)
  end
  return n
end

local function encode_f32_le(num)
  -- Use LuaJIT FFI if available for fast float encoding
  local ffi_available = false
  if jit and jit.status and require then
    local success, ffi_mod = pcall(function() 
      return dofile(minetest.get_modpath("moon") .. "/ffi.lua")
    end)
    if success and ffi_mod then
      local arr = ffi_mod.new("float[1]", num)
      return ffi_mod.string(arr, 4)
    end
  end
  
  -- Fallback: IEEE 754 float32 encoding (may be platform dependent)
  local sign = 0
  if num < 0 then sign = 1; num = -num end
  local mantissa, exponent = math.frexp(num)
  if num == 0 then
    return "\0\0\0\0"
  elseif not (num == num) then -- NaN
    return "\255\255\255\255"
  elseif num == math.huge then
    return "\0\0\128\127"
  end
  exponent = exponent + 126
  mantissa = (mantissa * 2 - 1) * 0x800000
  local b1 = mantissa % 256; mantissa = math.floor(mantissa / 256)
  local b2 = mantissa % 256; mantissa = math.floor(mantissa / 256)
  local b3 = mantissa % 128 + exponent * 128
  local b4 = sign * 128 + math.floor(exponent / 2)
  return string.char(b1, b2, b3, b4)
end

--------------------------------------------------------------------------
--  decode_f32_le  – Convert 4 little-endian bytes to an IEEE-754 float
--  s       : Lua string containing at least 4 bytes starting at offset
--  offset  : 1-based index of first byte (defaults to 1)
--------------------------------------------------------------------------
local function decode_f32_le(s, offset)
  offset = offset or 1
  assert(#s >= offset + 3, "decode_f32_le: need at least 4 bytes")

  ----------------------------------------------------------------------
  -- Fast path 1: LuaJIT with native FFI -------------------------------
  ----------------------------------------------------------------------
  if jit then
    local ok, ffi = pcall(function() 
      return dofile(minetest.get_modpath("moon") .. "/ffi.lua")
    end)
    if ok then
      local arr = ffi.new("float[1]")
      ffi.copy(arr, s:sub(offset, offset + 3), 4)
      return tonumber(arr[0])
    end
  end

  ----------------------------------------------------------------------
  -- Fast path 2: stock Lua 5.3+ with string.unpack --------------------
  ----------------------------------------------------------------------
  if string.unpack then
    -- '<f' → little-endian, single-precision float
    return (string.unpack("<f", s, offset))
  end

  ----------------------------------------------------------------------
  -- Portable pure-Lua fallback (no bit library required) --------------
  ----------------------------------------------------------------------
  local b1, b2, b3, b4 = s:byte(offset, offset + 3)

  -- sign, exponent, mantissa extraction
  local sign     = (b4 >= 128) and -1 or 1
  local exponent = ((b4 % 128) * 2) + math.floor(b3 / 128)   -- 0…255
  local mantissa = ((b3 % 128) * 65536) + (b2 * 256) + b1    -- 0…2²³-1

  -- special cases
  if exponent == 255 then
    if mantissa == 0 then        -- ±∞
      return sign * math.huge
    else                         -- NaN
      return 0/0
    end
  elseif exponent == 0 then      -- denormals / ±0
    if mantissa == 0 then
      return sign * 0.0
    else
      return sign * (mantissa / 2^23) * 2^-126
    end
  end

  -- normalised number
  return sign * (1 + mantissa / 2^23) * 2^(exponent - 127)
end


-- local function decode_f32_le(s, offset)
--   offset = offset or 1
--   if jit and jit.status and require then
-- dofile(minetest.get_modpath("moon") .. "/ffi.lua")
--     local arr = ffi.new("float[1]")
--     ffi.copy(arr, s:sub(offset, offset+3), 4)
--     return tonumber(arr[0])
--   else
--     -- Fallback: imprecise, only for emergency
--     return 0.0
--   end
-- end

local function encode_meta(tbl)
  local flags = tbl.flags or 0
  local material_id = tbl.material_id or ""
  local material_id_len = #material_id
  local port_id = tbl.port_id or 0
  local temperature = tbl.temperature or 0.0

  local out = {
    string.char(SCHEMA_VERSION),
    string.char(flags),
    string.char(material_id_len),
    material_id,
    encode_u64_le(port_id),
    encode_f32_le(temperature),
  }
  return table.concat(out)
end

local function decode_meta(s)
  if not (type(s) == "string") or #s < 15 then
    return nil
  end
  local version = s:byte(1)
  if not (version == SCHEMA_VERSION) then
    -- Future: migrate older version here if needed
    return nil
  end
  local flags = s:byte(2)
  local material_id_len = s:byte(3)
  local material_id = s:sub(4, 3 + material_id_len)
  local port_id_offset = 4 + material_id_len
  local port_id = decode_u64_le(s, port_id_offset)
  local temp_offset = port_id_offset + 8
  local temperature = decode_f32_le(s, temp_offset)
  return {
    flags = flags,
    material_id = material_id,
    port_id = port_id,
    temperature = temperature,
  }
end

return {
  SCHEMA_VERSION = SCHEMA_VERSION,
  encode_meta = encode_meta,
  decode_meta = decode_meta,
}
