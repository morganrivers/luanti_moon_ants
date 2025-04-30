local serialization = dofile(minetest.get_modpath("moon").."/voxels/serialization.lua")

local META_KEY = "moon_vx"

local function read(pos)
  if minetest and minetest.get_meta then
    local meta = minetest.get_meta(pos)
    local bin = meta:get_string(META_KEY)
    if bin == "" then return nil end
    return serialization.decode_meta(bin)
  else
    -- Testing mode - return the position as metadata for testing
    return pos
  end
end

local function write(pos, tbl)
  if minetest and minetest.get_meta then
    local meta = minetest.get_meta(pos)
    local bin = serialization.encode_meta(tbl)
    meta:set_string(META_KEY, bin)
  else
    -- Testing mode - no need to save anything
    return true
  end
end

return {
  read = read,
  write = write,
}

