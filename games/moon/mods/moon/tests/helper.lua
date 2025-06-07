-- local repo_root  = (...):match('^(.*)/tests/helper%.lua$')        -- path up to repo
-- _G.minetest      = _G.minetest or {}

-- function minetest.get_modpath(modname)
--   -- adjust if your directory layout differs
--   return repo_root .. '/mods/' .. modname
-- end



-- -- Make a mock `minetest` table if the real engine isn't running
-- _G.minetest = _G.minetest or {}

-- -- Absolute path of *this* file
-- local this_file = debug.getinfo(1, "S").source:sub(2)   -- trim leading '@'

-- -- The directory one level up from tests/  → the mod root
-- local mod_root = this_file:match("(.+)/tests/")

-- if not mod_root then
--   error("helper.lua: can't locate the mod root from path [" .. this_file .. "]")
-- end

-- -- Minimal stub: only the bit your tests need
-- function minetest.get_modpath(modname)
--   -- all tests refer to the current mod ('moon')
--   if modname ~= "moon" then
--     error("helper.lua: mock get_modpath only handles the 'moon' mod")
--   end
--   return mod_root
-- end

-- -- Pull in whatever helpers you keep in busted.lua (if it exists)
-- local busted_helper = mod_root .. "/busted.lua"
-- pcall(dofile, busted_helper)   -- it's OK if the file isn't there





-- Create the `minetest` global
_G.minetest = _G.minetest or {}

-- Try to resolve the absolute path
local function get_mod_root()
  local f = io.popen("pwd")
  if not f then
    error("helper.lua: cannot resolve working directory (pwd)")
  end
  local pwd = f:read("*l")
  f:close()

  -- Remove trailing slash if any
  pwd = pwd:gsub("/$", "")

  -- If we're inside tests/, remove that
  if pwd:match("/tests$") then
    return pwd:match("(.+)/tests$")
  else
    return pwd
  end
end

local mod_root = get_mod_root()

function minetest.get_modpath(modname)
  if modname ~= "moon" then
    error("helper.lua: mock get_modpath only supports 'moon', got ["..modname.."]")
  end
  return mod_root
end

-- Optionally load busted helpers, but don't fail if missing
local busted_helper = mod_root .. "/busted.lua"
local ok, err = pcall(dofile, busted_helper)
if not ok then
  -- You can comment this out if not critical
  print("helper.lua: busted.lua not found or failed to load: " .. tostring(err))
end
