-- solvers/chemistry.lua
dofile(minetest.get_modpath("moon") .. "/constants.lua")
dofile(minetest.get_modpath("moon") .. "/util.lua")
dofile(minetest.get_modpath("moon") .. "/materials/registry.lua")
dofile(minetest.get_modpath("moon") .. "/materials/reactions.lua")
dofile(minetest.get_modpath("moon") .. "/voxels/metadata.lua")
dofile(minetest.get_modpath("moon") .. "/islands/detector.lua")

-- local bit = bit32 or bit DMR no idea what this was supposed to be

local function step(island, dt)
  local dirty = false
  -- Preload flags for speed
  local MATERIAL = materials.flags

  -- For each voxel in the island
  for pos_hash, _ in pairs(island.voxels) do
    -- Read voxel metadata
    local pos = util.unhash3(pos_hash)
    local meta = voxels_meta.read(pos)
    if not meta then goto continue end

    local mat = materials.get(meta.material_id)
    if not mat or mat.reaction_id == 0 then goto continue end
    local temp = meta.temp or mat.baseline_T or 293

    -- Find all reactions enabled for this material
    for _, rxn in ipairs(reactions) do
      if (bit.band(mat.flags, rxn.react_flags) == rxn.react_flags)
         and temp >= rxn.min_temp
         and rxn.id == mat.reaction_id
      then
        -- Use meta.reaction_timer (in seconds), or initialize if nil
        meta.reaction_timer = (meta.reaction_timer or 0) + dt
        -- Accumulate time above threshold
        if meta.reaction_timer >= rxn.duration then
          -- Apply reaction: update flags and material_id
          local new_id = materials.find_by_flag(rxn.product_flags)[1]
          if new_id and not (new_id == meta.material_id) then
            meta.material_id = new_id
            meta.flags = rxn.product_flags
            meta.reaction_timer = nil
            voxels_meta.write(pos, meta)
            dirty = true
            -- Clear active bit if present, so no further chemistry until reactivated
            if meta.active then
              meta.active = false
            end
          end
        else
          -- Not done yet, keep accumulating
          voxels_meta.write(pos, meta)
        end
        -- Only apply one reaction per tick per voxel
        break
      else
        -- If temp drops below, reset timer
        meta.reaction_timer = nil
      end
    end

    ::continue::
  end
  return dirty
end

return { step = step }
