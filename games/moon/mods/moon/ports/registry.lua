-- ports/registry.lua
-- Stores every port instance keyed by voxel position and holds current latch/state values

local util = require("util")
local types = require("ports/types")

local registry = {}
local port_id_counter = 0       -- 64-bit wrap-around
local id_modulo = 2^64

-- port_id (uint64) -> {pos_hash, face, class, state}
local ports = {}

-- pos_hash (int) -> { [face]=port_id, ... }
local ports_by_voxel = {}

-- Helpers
local function next_id()
  port_id_counter = (port_id_counter + 1) % id_modulo
  if port_id_counter == 0 then
    port_id_counter = 1
  end
  return port_id_counter
end

-- API

-- Add a port, given position hash, face (0..5), class (enum), and optional state table
function registry.add(pos_hash, face, class, state)
  assert(type(pos_hash) == "number", "pos_hash must be number")
  assert(face >= 0 and face <= 5, "face must be 0..5")
  assert(types[class], "Invalid port class")
  local id = next_id()
  local state_tbl = state or {}
  ports[id] = {
    pos_hash = pos_hash,
    face = face,
    class = class,
    state = state_tbl,
  }
  if not ports_by_voxel[pos_hash] then ports_by_voxel[pos_hash] = {} end
  ports_by_voxel[pos_hash][face] = id
  return id
end

-- Remove a port by id
function registry.remove(id)
  local rec = ports[id]
  if not rec then return false end
  local pos_hash, face = rec.pos_hash, rec.face
  if ports_by_voxel[pos_hash] then
    ports_by_voxel[pos_hash][face] = nil
    -- If table empty, remove to prevent leak
    if next(ports_by_voxel[pos_hash]) == nil then
      ports_by_voxel[pos_hash] = nil
    end
  end
  ports[id] = nil
  return true
end

-- Lookup port record by id
function registry.lookup(id)
  return ports[id]
end

-- Get all port_ids for a given pos_hash
function registry.ports_for_voxel(pos_hash)
  local by_face = ports_by_voxel[pos_hash]
  if not by_face then return function() end end
  local face_iter, state, var = pairs(by_face)
  return function()
    local face, id = face_iter(state, var)
    var = face
    return id
  end
end

-- For debug or save: full port table
function registry._all_ports()
  return ports
end

return registry