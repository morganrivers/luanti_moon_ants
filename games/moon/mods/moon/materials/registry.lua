-- materials/registry.lua
dofile(minetest.get_modpath("moon") .. "/materials/flags.lua")
local bit = require("bit")  -- LuaJIT's bit library

local registry = {}
local _by_flag = {}

-- Internal helper to update flag index
local function _index_by_flag(id, mat)
  for b = 0, 7 do
    local flag = bit.lshift(1, b)
    if not (bit.band(mat.flags, flag) == 0) then
      _by_flag[flag] = _by_flag[flag] or {}
      _by_flag[flag][id] = true
    end
  end
end

local api = {}

-- Adds or replaces a material definition
-- @param id (string): short key, e.g. "Fe"
-- @param def (table): {name, flags, rho, epsilon_r, mu_r, density, baseline_T, reaction_id}
function api.add(id, def)
  assert(type(id) == "string" and not (id == ""), "Material id must be nonempty string")
  assert(type(def) == "table", "Material definition must be a table")
  assert(type(def.name) == "string" and not (def.name == ""), "Material must have a name")
  assert(type(def.flags) == "number" and def.flags >= 0 and def.flags <= 0xFF, "flags must be uint8")
  assert(type(def["rho"]) == "number", "rho (resistivity) must be a number")
  assert(type(def["epsilon_r"]) == "number", "epsilon_r (relative permittivity) must be a number")
  assert(type(def["mu_r"]) == "number", "mu_r (relative permeability) must be a number")
  assert(type(def.density) == "number", "density must be a number")
  assert(type(def.baseline_T) == "number", "baseline_T must be a number")
  assert(type(def.reaction_id) == "number" and def.reaction_id >= 0 and def.reaction_id <= 0xFFFF, "reaction_id must be uint16")
  registry[id] = {
    name        = def.name,
    flags       = def.flags,
    ["rho"]       = def["rho"],
    ["epsilon_r"]     = def["epsilon_r"],
    ["mu_r"]     = def["mu_r"],
    density     = def.density,
    baseline_T  = def.baseline_T,
    reaction_id = def.reaction_id,
  }
  _index_by_flag(id, registry[id])
end

-- Retrieves a material definition by id
-- @param id (string)
-- @return table or nil
function api.get(id)
  return registry[id]
end

-- Returns an array of material definitions for all materials containing all bits in mask
-- @param flag_mask (integer)
-- @return array of defs
function api.find_by_flag(flag_mask)
  local result = {}
  for id, def in pairs(registry) do
    if bit.band(def.flags, flag_mask) == flag_mask then
      table.insert(result, def)
    end
  end
  return result
end

api._registry = registry
return api

