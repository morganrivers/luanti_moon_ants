-- solvers/logic.lua
-- Evaluates transistor/relay/diode behavior and updates digital port latches

dofile(minetest.get_modpath("moon") .. "/constants.lua")
dofile(minetest.get_modpath("moon") .. "/util.lua")
dofile(minetest.get_modpath("moon") .. "/materials/registry.lua")
dofile(minetest.get_modpath("moon") .. "/ports/registry.lua")
dofile(minetest.get_modpath("moon") .. "/ports/types.lua")
dofile(minetest.get_modpath("moon") .. "/ports/api.lua")
dofile(minetest.get_modpath("moon") .. "/voxels/metadata.lua")

local PORT_CLASS = ports_types.classes
dofile(minetest.get_modpath("moon") .. "/materials/flags.lua")

-- Logic solver: step(island, dt)
-- Returns true if any port/voxel state changed (for downstream solvers)
local function step(island, dt)
  local dirty = false

  -- Step 1: Iterate all SENSOR ports in island
  if island.ports then
    for port_id in pairs(island.ports) do
      local port = ports_registry.lookup(port_id)
      if port and port.class == PORT_CLASS.SENSOR then
        -- For now, SENSORs are assumed to be read-only, no update to actuators here
        -- But in future, could process e.g. thresholding logic
        -- Example: read its value and gate digital output (unimplemented)
        -- Placeholder: nothing to do
      end
    end
  end

  -- Step 2: Iterate all voxels; process transistor/relay/diode logic
  if island.voxels then
    for pos_hash in pairs(island.voxels) do
      -- Read voxel metadata
      local pos = util.unhash_pos(pos_hash)
      local meta = voxels_metadata.read(pos)
      if meta and util.has_flag(meta.flags, MATERIAL_FLAGS.TRANSISTOR) then
        -- For a transistor voxel:
        -- - Find gate port and its voltage
        -- - Compare to material threshold (use ε_r as threshold placeholder)
        -- - Set ACTUATOR port command if this is a coil

        -- Find the port attached to this voxel, if any
        local port_id = meta.port_id
        if port_id and port_id ~= 0 then
          local port = ports_registry.lookup(port_id)
          if port and port.class == PORT_CLASS.ACTUATOR then
            -- Find gate port
            -- For now, we assume a convention: the transistor's port "gate" voltage is stored as "gate_v"
            -- or it is connected to a POWER port on the same voxel (for simplicity)
            local gate_voltage = 0
            local found_gate = false
            -- Search for a SENSOR or POWER port on this voxel
            for other_port_id in pairs(island.ports) do
              local other_port = ports_registry.lookup(other_port_id)
              if other_port
                and other_port.pos_hash == pos_hash
                and (other_port.class == PORT_CLASS.POWER or other_port.class == PORT_CLASS.SENSOR) then
                -- For POWER port, assume voltage field
                if other_port.state and other_port.state.voltage then
                  gate_voltage = other_port.state.voltage
                  found_gate = true
                  break
                elseif other_port.state and other_port.state.value then
                  gate_voltage = other_port.state.value * 10 -- scale 0-1 to a voltage (arbitrary)
                  found_gate = true
                  break
                end
              end
            end

            if found_gate then
              -- Get threshold from material
              local mat = materials.get(meta.material_id)
              local threshold = mat and mat.ε_r or 1 -- Use ε_r as a stand-in for threshold voltage

              -- If gate voltage > threshold, activate actuator
              local prev_command = port.state and port.state.command or nil
              local new_command = (gate_voltage > threshold) and 1 or 0
              if prev_command ~= new_command then
                ports_api.write(port_id, "command", new_command)
                dirty = true
              end
            end
          end
        end
      elseif meta and util.has_flag(meta.flags, MATERIAL_FLAGS.RELAY) then
        -- For a relay: similar logic, but controlling ACTUATOR based on POWER port current
        local port_id = meta.port_id
        if port_id and port_id ~= 0 then
          local port = ports_registry.lookup(port_id)
          if port and port.class == PORT_CLASS.ACTUATOR then
            -- Find POWER port attached to this voxel
            local coil_current = 0
            local found_coil = false
            for other_port_id in pairs(island.ports) do
              local other_port = ports_registry.lookup(other_port_id)
              if other_port
                and other_port.pos_hash == pos_hash
                and other_port.class == PORT_CLASS.POWER
                and other_port.state
                and other_port.state.current_A then
                coil_current = other_port.state.current_A
                found_coil = true
                break
              end
            end

            if found_coil then
              -- Use ε_r as relay trigger current threshold (placeholder)
              local mat = materials.get(meta.material_id)
              local threshold = mat and mat.ε_r or 0.05
              local prev_command = port.state and port.state.command or nil
              local new_command = (math.abs(coil_current) > threshold) and 1 or 0
              if prev_command ~= new_command then
                ports_api.write(port_id, "command", new_command)
                dirty = true
              end
            end
          end
        end
      elseif meta and util.has_flag(meta.flags, MATERIAL_FLAGS.DIODE) then
        -- For a diode: simply set ACTUATOR port command based on voltage polarity
        local port_id = meta.port_id
        if port_id and port_id ~= 0 then
          local port = ports_registry.lookup(port_id)
          if port and port.class == PORT_CLASS.ACTUATOR then
            local v_a = 0
            local v_b = 0
            -- Find two POWER ports on this voxel, representing anode and cathode
            local found = 0
            for other_port_id in pairs(island.ports) do
              local other_port = ports_registry.lookup(other_port_id)
              if other_port
                and other_port.pos_hash == pos_hash
                and other_port.class == PORT_CLASS.POWER
                and other_port.state
                and other_port.state.voltage then
                if found == 0 then
                  v_a = other_port.state.voltage
                  found = 1
                elseif found == 1 then
                  v_b = other_port.state.voltage
                  found = 2
                  break
                end
              end
            end
            if found == 2 then
              local prev_command = port.state and port.state.command or nil
              local new_command = (v_a > v_b) and 1 or 0
              if prev_command ~= new_command then
                ports_api.write(port_id, "command", new_command)
                dirty = true
              end
            end
          end
        end
      end
    end
  end

  return dirty
end

return {
  step = step
}
