-- materials/registry.lua
-- local flags = require("materials.flags") # DMR must comment back in

local registry = {}
local _by_flag = {}

-- Internal helper to update flag index
local function _index_by_flag(id, mat)
  for bit = 0, 7 do
    local flag = bit32.lshift(1, bit)
    if not (bit32.band(mat.flags, flag) == 0) then
      _by_flag[flag] = _by_flag[flag] or {}
      _by_flag[flag][id] = true
    end
  end
end

local api = {}

-- Adds or replaces a material definition
-- @param id (string): short key, e.g. "Fe"
-- @param def (table): {name, flags, ρ, ε_r, μ_r, density, baseline_T, reaction_id}
function api.add(id, def)
  assert(type(id) == "string" and id ~= "", "Material id must be nonempty string")
  assert(type(def) == "table", "Material definition must be a table")
  assert(type(def.name) == "string" and def.name ~= "", "Material must have a name")
  assert(type(def.flags) == "number" and def.flags >= 0 and def.flags <= 0xFF, "flags must be uint8")
  assert(type(def["ρ"]) == "number", "ρ (resistivity) must be a number")
  assert(type(def["ε_r"]) == "number", "ε_r (relative permittivity) must be a number")
  assert(type(def["μ_r"]) == "number", "μ_r (relative permeability) must be a number")
  assert(type(def.density) == "number", "density must be a number")
  assert(type(def.baseline_T) == "number", "baseline_T must be a number")
  assert(type(def.reaction_id) == "number" and def.reaction_id >= 0 and def.reaction_id <= 0xFFFF, "reaction_id must be uint16")
  registry[id] = {
    name        = def.name,
    flags       = def.flags,
    ["ρ"]       = def["ρ"],
    ["ε_r"]     = def["ε_r"],
    ["μ_r"]     = def["μ_r"],
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

-- Returns a table mapping ids to definitions for all materials containing all bits in mask
-- @param flag_mask (integer)
-- @return table: id -> def
function api.find_by_flag(flag_mask)
  local result = {}
  for id, def in pairs(registry) do
    if bit32.band(def.flags, flag_mask) == flag_mask then
      result[id] = def
    end
  end
  return result
end

api._registry = registry
return api
