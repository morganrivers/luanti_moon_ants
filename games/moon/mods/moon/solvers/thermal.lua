dofile(minetest.get_modpath("moon") .. "/constants.lua")
dofile(minetest.get_modpath("moon") .. "/util.lua")
dofile(minetest.get_modpath("moon") .. "/materials/registry.lua")
dofile(minetest.get_modpath("moon") .. "/bonds/api.lua")
dofile(minetest.get_modpath("moon") .. "/bonds/types.lua")
dofile(minetest.get_modpath("moon") .. "/voxels/metadata.lua")
dofile(minetest.get_modpath("moon") .. "/ports/registry.lua")

local THERMAL_BOND = bonds_types.THERMAL
dofile(minetest.get_modpath("moon") .. "/ports/types.lua")

local MAX_ITERS    = constants.MAX_SOLVER_ITERS or 8
local DT           = constants.THERMAL_DT or 0.002 -- 2 ms recommended
local VOXEL_VOL    = (constants.VOXEL_EDGE or 0.05) ^ 3

-- Pre-allocate static buffers for tight voxel loops
local _adj_bonds   = {}
local _dirty_vox   = {}

local function get_voxel_heat_capacity(voxel)
  -- c = material.density * specific_heat * volume (J/K)
  -- For now, assume specific_heat = 500 J/kg·K (default fallback)
  local mat = materials.get(voxel.material_id)
  local density = mat and mat.density or 2000
  local c = mat and mat.specific_heat or 500
  return density * c * VOXEL_VOL
end

local function sum_joule_heating(voxel, dt)
  -- Only applies if the voxel has a POWER port (electrical current)
  if voxel.port_id == 0 then return 0 end
  local port = ports_reg.lookup(voxel.port_id)
  if not port or not (port.class == POWER_PORT) then return 0 end
  local I = port.state_tbl.current_A or 0
  local mat = materials.get(voxel.material_id)
  local R = mat and mat.rho or 0
  if R <= 0 then return 0 end
  -- P = I^2 * R * dt
  return (I * I * R) * dt
end

local function sum_reaction_enthalpy(voxel, dt)
  -- Chemistry solver triggers reactions, but we heat during dwell
  -- If a reaction is ongoing, apply enthalpy/second as heat
  if not voxel.reaction or not voxel.reaction.enthalpy then return 0 end
  return voxel.reaction.enthalpy * dt / (voxel.reaction.duration or 1)
end

local function step(island, dt)
  -- Returns true if any voxel temp changed by more than epsilon
  local voxels = island.voxels
  local bonds  = island.bonds
  local dirty  = false
  local eps    = 1e-3
  local changed_voxels = _dirty_vox
  for k in pairs(changed_voxels) do changed_voxels[k] = nil end

  -- First, for each voxel, sum heat flux from all thermal bonds
  for vx_hash, voxel in pairs(voxels) do
    local meta = vox_meta.read(voxel.pos)
    if not meta then
      -- Skip if no metadata
    else
      local T = meta.temperature or meta.temp or meta.T or 293
      local mat = materials.get(meta.material_id)
      if not mat then
        -- Skip if no material
      else
        local C = get_voxel_heat_capacity(meta)
        local Q_total = 0

        -- Gather all bonds for this voxel
        for b in bonds_api.pairs_for_voxel(vx_hash) do
          if b.type == THERMAL_BOND then
            -- Find the other voxel and its temp
            local other_hash = (b.voxel_A == vx_hash) and b.voxel_B or b.voxel_A
            local other_vox = voxels[other_hash]
            if other_vox then
              local metaB = vox_meta.read(other_vox.pos)
              if metaB then
                local TB = metaB.temperature or metaB.temp or metaB.T or 293
                -- k is in W/m·K, assume bond length = 1 voxel edge, area = voxel face
                local k = b.state.k or 1
                local L = constants.VOXEL_EDGE or 0.05 -- m
                local A = L * L                      -- m²
                local dQ = (k * A / L) * (TB - T) * dt
                Q_total = Q_total + dQ
              end
            end
          end
        end

        -- Add Joule heating (from electrical)
        Q_total = Q_total + sum_joule_heating(meta, dt)
        -- Add reaction enthalpy (if present)
        Q_total = Q_total + sum_reaction_enthalpy(meta, dt)

        -- Integrate temperature
        local delta_T = Q_total / C
        if math.abs(delta_T) > eps then
          changed_voxels[vx_hash] = true
          dirty = true
        end
        meta.temperature = (meta.temperature or 293) + delta_T
        vox_meta.write(voxel.pos, meta)
      end
    end
  end

  return dirty
end

return { step = step }

