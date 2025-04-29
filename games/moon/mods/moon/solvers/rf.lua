```lua
-- solvers/rf.lua
-- Serializes and routes packets between RF_PORTs with range/line-of-sight and contention logic

local constants   = require("constants")
local util        = require("util")
local ports       = require("ports")
local ports_api   = require("ports.api")
local ports_types = require("ports.types")

-- RF solver constants
local RF_PORT    = ports_types.RF_PORT
local RF_RANGE   = constants.RF_RANGE or 32 -- meters; fallback if not set in constants

-- Minetest vector helpers
local vector = vector

-- Static buffer to avoid allocations per tick
local _rf_transmitters = {}
local _rf_receivers = {}
local _rf_receivers_set = {}

local function clear_table(t)
  for k in pairs(t) do t[k] = nil end
end

local function port_is_active_rf(port)
  return port.class == RF_PORT and port.state and port.state.tx
end

local function port_is_rf(port)
  return port.class == RF_PORT
end

local function distance_squared(a, b)
  local dx = a.x - b.x
  local dy = a.y - b.y
  local dz = a.z - b.z
  return dx*dx + dy*dy + dz*dz
end

local function get_world_pos_from_port(port)
  -- Derive world pos from pos_hash; assume util.unhash returns x,y,z
  local x, y, z = util.unhash(port.pos_hash)
  return {x = x, y = y, z = z}
end

local function check_los(pos1, pos2)
  -- Uses Minetest's line_of_sight, fallback to true if unavailable
  if minetest and minetest.line_of_sight then
    return minetest.line_of_sight(pos1, pos2, 1)
  else
    return true
  end
end

local function transmit_rf_packet(tx_port, rx_port, payload)
  -- Deliver packet payload table to receiver port
  ports_api.write(rx_port.id, "rx", payload)
end

local function step(island, dt)
  -- 1. Gather all RF_PORT ports in this island
  -- 2. Find transmitters (ports with .tx non-nil this tick)
  -- 3. For each transmitter, deliver packet to all receivers in range
  -- 4. Return true if any packets were delivered

  clear_table(_rf_transmitters)
  clear_table(_rf_receivers)
  clear_table(_rf_receivers_set)

  local ports_list = island.ports
  if not ports_list or next(ports_list) == nil then
    return false
  end

  -- First, collect transmitters and receivers
  for port_id in pairs(ports_list) do
    local port = ports.registry.lookup(port_id)
    if port and port_is_rf(port) then
      if port_is_active_rf(port) then
        _rf_transmitters[#_rf_transmitters+1] = port
      else
        _rf_receivers[#_rf_receivers+1] = port
        _rf_receivers_set[port_id] = true
      end
    end
  end

  if #_rf_transmitters == 0 then
    return false
  end

  local dirty = false

  -- For each transmitter, deliver to receivers in range
  for i=1,#_rf_transmitters do
    local tx = _rf_transmitters[i]
    local tx_pos = get_world_pos_from_port(tx)
    local payload = tx.state.tx
    if not payload then
      goto continue_tx
    end

    -- Optionally, allow transmitters to receive their own packets (loopback)
    for j=1,#_rf_receivers do
      local rx = _rf_receivers[j]
      if rx.id == tx.id then goto continue_rx end
      local rx_pos = get_world_pos_from_port(rx)
      local d2 = distance_squared(tx_pos, rx_pos)
      if d2 > RF_RANGE*RF_RANGE then goto continue_rx end

      if check_los(tx_pos, rx_pos) then
        transmit_rf_packet(tx, rx, payload)
        dirty = true
      end

      ::continue_rx::
    end

    -- Clear the tx field for this tick (one-shot semantics)
    tx.state.tx = nil

    ::continue_tx::
  end

  return dirty
end

return {
  step = step
}
```
