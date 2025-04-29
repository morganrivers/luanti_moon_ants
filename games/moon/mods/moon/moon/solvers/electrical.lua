-- solvers/electrical.lua
-- Kirchhoff node solver producing voltages/currents for each ELECTRIC bond graph

dofile(minetest.get_modpath("moon") .. "/constants.lua")
dofile(minetest.get_modpath("moon") .. "/util.lua")
dofile(minetest.get_modpath("moon") .. "/materials/registry.lua")
dofile(minetest.get_modpath("moon") .. "/bonds/types.lua")
dofile(minetest.get_modpath("moon") .. "/bonds/registry.lua")
dofile(minetest.get_modpath("moon") .. "/ports/types.lua")
dofile(minetest.get_modpath("moon") .. "/ports/api.lua")
dofile(minetest.get_modpath("moon") .. "/voxels/metadata.lua")

local MAX_ITERS      = constants.MAX_SOLVER_ITERS or 128
local VOLTAGE_EPS    = 1e-5
local NIL_NODE_ID    = constants.NIL_NODE_ID or 0xFFFF

-- Small static buffers to avoid per-node alloc
local node_map      = {}   -- [pos_hash] = node_id
local node_list     = {}   -- [node_id] = {pos_hash=, port_id=, is_port=, G=, I=, V=}
local bond_edges    = {}   -- { {a=, b=, R=}, ... }
local port_nodes    = {}   -- [node_id] = true if POWER port

local function clear_buffers()
  for k in pairs(node_map) do node_map[k] = nil end
  for k in pairs(node_list) do node_list[k] = nil end
  for k in pairs(bond_edges) do bond_edges[k] = nil end
  for k in pairs(port_nodes) do port_nodes[k] = nil end
end

local function build_circuit_graph(island)
  -- Step 1: Build node_list from all voxels connected by ELECTRIC bonds
  local node_id = 0
  -- Map pos_hash to node_id and populate node_list
  for pos_hash in pairs(island.voxels) do
    local voxel = island.voxels[pos_hash]
    local meta = voxels_meta.read(voxel.pos)
    -- Only consider voxels with CONDUCTOR flag
    local mat = materials.get(meta.material_id)
    if mat and util.has_flag(mat.flags, materials.flags.CONDUCTOR) then
      node_id = node_id + 1
      node_map[pos_hash] = node_id
      -- Check for port
      local port_id = meta.port_id or 0
      local port = (port_id ~= 0) and ports_api.read(port_id, "class") or nil
      node_list[node_id] = {
        pos_hash = pos_hash,
        port_id = port_id,
        is_port = (port_id ~= 0 and port == ports_types.POWER) or false,
        G = 0,
        I = 0,
        V = 0,
      }
      if node_list[node_id].is_port then
        port_nodes[node_id] = true
      end
    end
  end

  -- Step 2: Build bond_edges list from ELECTRIC bonds
  for pos_hash in pairs(island.voxels) do
    for _, bond in bonds_registry.pairs_for_voxel(pos_hash) do
      if bond.type == bonds_types.ELECTRIC then
        local hashA, hashB = bond.pos_hash_A, bond.pos_hash_B
        local nodeA, nodeB = node_map[hashA], node_map[hashB]
        if nodeA and nodeB and nodeA < nodeB then
          -- Resistance from materials, fallback to small R if missing
          local metaA = voxels_meta.read(bond.pos_A)
          local matA  = materials.get(metaA.material_id)
          local metaB = voxels_meta.read(bond.pos_B)
          local matB  = materials.get(metaB.material_id)
          local rhoA  = (matA and matA.ρ) or 1.0
          local rhoB  = (matB and matB.ρ) or 1.0
          local R     = (rhoA + rhoB) * constants.VOXEL_EDGE_LEN / 2
          table.insert(bond_edges, {a = nodeA, b = nodeB, R = R, bond = bond})
        end
      end
    end
  end
end

local function apply_port_currents()
  -- Set up current injections and voltage constraints from POWER ports
  for node_id, node in pairs(node_list) do
    if node.is_port and node.port_id ~= 0 then
      -- Ports may act as voltage source (V), or current source (I), or sink (load)
      local V_set = ports_api.read(node.port_id, "voltage")
      local I_set = ports_api.read(node.port_id, "current_A")
      if V_set ~= nil then
        node.V = V_set
        node.G = 1e9  -- Pin voltage: acts as ideal voltage source (large conductance)
        node.I = 0
      elseif I_set ~= nil then
        node.I = I_set
        node.G = 0
      end
    end
  end
end

local function gauss_seidel_solve(n_nodes)
  -- Simple iterative nodal analysis
  local V_prev = {}
  local converged = false
  local iter = 0

  -- Initial guess: 0 V everywhere, or as set by port voltage
  for i = 1, n_nodes do
    V_prev[i] = node_list[i].V or 0
    node_list[i].V = V_prev[i]
  end

  while not converged and iter < MAX_ITERS do
    iter = iter + 1
    converged = true
    for i = 1, n_nodes do
      local node = node_list[i]
      if node.G > 1e6 then
        -- Voltage pin, skip
        node.V = node.V
      else
        -- Sum conductances for this node
        local G_sum, I_sum = 0, node.I
        local V_neighbors = 0
        for _, edge in ipairs(bond_edges) do
          if edge.a == i then
            local j = edge.b
            local G = 1/edge.R
            G_sum = G_sum + G
            V_neighbors = V_neighbors + G * (node_list[j].V or 0)
          elseif edge.b == i then
            local j = edge.a
            local G = 1/edge.R
            G_sum = G_sum + G
            V_neighbors = V_neighbors + G * (node_list[j].V or 0)
          end
        end
        if G_sum > 0 then
          local V_new = (I_sum + V_neighbors) / G_sum
          if math.abs(V_new - node.V) > VOLTAGE_EPS then
            converged = false
          end
          node.V = V_new
        end
      end
    end
  end
end

local function write_results_to_ports()
  local changed = false
  for node_id, node in pairs(node_list) do
    if node.is_port and node.port_id ~= 0 then
      -- Write computed voltage back to port state
      local oldV = ports_api.read(node.port_id, "voltage")
      if math.abs((oldV or 0) - node.V) > VOLTAGE_EPS then
        ports_api.write(node.port_id, "voltage", node.V)
        changed = true
      end
      -- Compute port current: sum of outgoing bond currents
      local I_sum = 0
      for _, edge in ipairs(bond_edges) do
        if edge.a == node_id then
          local Vother = node_list[edge.b].V or 0
          I_sum = I_sum + (node.V - Vother) / edge.R
        elseif edge.b == node_id then
          local Vother = node_list[edge.a].V or 0
          I_sum = I_sum + (node.V - Vother) / edge.R
        end
      end
      local oldI = ports_api.read(node.port_id, "current_A")
      if oldI == nil or math.abs(oldI - I_sum) > 1e-7 then
        ports_api.write(node.port_id, "current_A", I_sum)
        changed = true
      end
    end
  end
  return changed
end

local function step(island, dt)
  clear_buffers()
  build_circuit_graph(island)
  local n_nodes = 0
  for _ in pairs(node_list) do n_nodes = n_nodes + 1 end
  if n_nodes == 0 then return false end
  apply_port_currents()
  gauss_seidel_solve(n_nodes)
  local dirty = write_results_to_ports()
  return dirty
end

return {
  step = step
}
