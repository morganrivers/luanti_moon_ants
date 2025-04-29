local serialization = dofile(minetest.get_modpath("moon").."/voxels/serialization.lua")

local META_KEY = "moon_vx"

local function read(pos)
  local meta = minetest.get_meta(pos)
  local bin = meta:get_string(META_KEY)
  if bin == "" then return nil end
  return serialization.decode_meta(bin)
end

local function write(pos, tbl)
  local meta = minetest.get_meta(pos)
  local bin = serialization.encode_meta(tbl)
  meta:set_string(META_KEY, bin)
end

return {
  read = read,
  write = write,
}

