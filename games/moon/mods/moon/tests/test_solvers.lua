dofile(minetest.get_modpath("moon") .. "/busted.lua")
--local assert = busted.assert

-- Mock/require subsystems
dofile(minetest.get_modpath("moon") .. "/constants.lua")
dofile(minetest.get_modpath("moon") .. "/util.lua")

local materials_flags = dofile(minetest.get_modpath("moon") .. "/materials/flags.lua")
local materials_registry = dofile(minetest.get_modpath("moon") .. "/materials/registry.lua")
local materials_reactions = dofile(minetest.get_modpath("moon") .. "/materials/reactions.lua")

local bonds_types = dofile(minetest.get_modpath("moon") .. "/bonds/types.lua")
local bonds_registry = dofile(minetest.get_modpath("moon") .. "/bonds/registry.lua")
local bonds_api = dofile(minetest.get_modpath("moon") .. "/bonds/api.lua")

local types = dofile(minetest.get_modpath("moon") .. "/ports/types.lua")
local ports_registry = dofile(minetest.get_modpath("moon") .. "/ports/registry.lua")
local ports_api = dofile(minetest.get_modpath("moon") .. "/ports/api.lua")

local voxels_metadata = dofile(minetest.get_modpath("moon") .. "/voxels/metadata.lua")
dofile(minetest.get_modpath("moon") .. "/voxels/serialization.lua")

local islands_detector = dofile(minetest.get_modpath("moon") .. "/islands/detector.lua")
local islands_queue = dofile(minetest.get_modpath("moon") .. "/islands/queue.lua")

local electrical = dofile(minetest.get_modpath("moon") .. "/solvers/electrical.lua")
local logic = dofile(minetest.get_modpath("moon") .. "/solvers/logic.lua")
local mechanical = dofile(minetest.get_modpath("moon") .. "/solvers/mechanical.lua")
local thermal = dofile(minetest.get_modpath("moon") .. "/solvers/thermal.lua")
local chemistry = dofile(minetest.get_modpath("moon") .. "/solvers/chemistry.lua")
local material_flow = dofile(minetest.get_modpath("moon") .. "/solvers/material_flow.lua")
local rf = dofile(minetest.get_modpath("moon") .. "/solvers/rf.lua")
local mining = dofile(minetest.get_modpath("moon") .. "/solvers/mining.lua")

-- Mocked map and registries
local test_world = {}
local function set_voxel(pos, tbl)
  local key = util.hash(pos)
  test_world[key] = tbl
end

local function get_voxel(pos)
  local key = util.hash(pos)
  return test_world[key]
end

-- Patch voxels_metadata to use our test map
voxels_metadata.read = get_voxel
voxels_metadata.write = set_voxel

-- Mock port/bond registries for test only (no side effects)
ports_registry._store = {}
ports_registry._next_id = 1
function ports_registry.add(port)
  local id = ports_registry._next_id
  ports_registry._next_id = ports_registry._next_id + 1
  ports_registry._store[id] = port
  return id
end
function ports_registry.lookup(id)
  return ports_registry._store[id]
end
function ports_registry.ports_for_voxel(pos_hash)
  local result = {}
  for id, port in pairs(ports_registry._store) do
    if port.pos_hash == pos_hash then
      table.insert(result, port)
    end
  end
  return result
end
function ports_registry.remove(id)
  ports_registry._store[id] = nil
end

bonds_registry._store = {}
function bonds_registry._bond_key(pa, fa, pb, fb)
  -- simple key for symmetry
  if pa < pb or (pa == pb and fa < fb) then
    return ("%d:%d|%d:%d"):format(pa, fa, pb, fb)
  else
    return ("%d:%d|%d:%d"):format(pb, fb, pa, fa)
  end
end
function bonds_registry.insert(pa, fa, pb, fb, rec)
  local k = bonds_registry._bond_key(pa, fa, pb, fb)
  bonds_registry._store[k] = rec
end
function bonds_registry.get(pa, fa)
  for k, rec in pairs(bonds_registry._store) do
    if k:find("^"..pa..":"..fa) or k:find("|"..pa..":"..fa) then
      return rec
    end
  end
end
function bonds_registry.pairs_for_voxel(pos_hash)
  local result = {}
  for k, rec in pairs(bonds_registry._store) do
    if k:find("^"..pos_hash..":") or k:find("|"..pos_hash..":") then
      table.insert(result, rec)
    end
  end
  return result
end
function bonds_registry.clear()
  bonds_registry._store = {}
end

-- Minimal material and bond filling for tests
materials_registry._store = {}
function materials_registry.add(id, tbl)
  materials_registry._store[id] = tbl
end
function materials_registry.get(id)
  return materials_registry._store[id]
end

-- === Helper for ticking solvers on a single island ===
local function run_solvers(island, dt, passes)
  for i = 1, passes do
    electrical.step(island, dt)
    logic.step(island, dt)
    mechanical.step(island, dt)
    thermal.step(island, dt)
    chemistry.step(island, dt)
    material_flow.step(island, dt)
    rf.step(island, dt)
    mining.step(island, dt)
  end
end

-- === TESTS ===

describe("Primitive engine solvers", function()
  before_each(function()
    -- Reset everything
    test_world = {}
    ports_registry._store = {}
    ports_registry._next_id = 1
    bonds_registry.clear()
    materials_registry._store = {}
  end)

  it("RC circuit: 3 nodes, 5V source, resistor, capacitor", function()
    -- Material definitions
    materials_registry.add("Cu",   {name="Copper", flags=materials_flags.CONDUCTOR, rho=1.68e-8, epsilon_r=1, mu_r=1, density=8960, baseline_T=293, reaction_id=0})
    materials_registry.add("C",    {name="Carbon", flags=materials_flags.CONDUCTOR, rho=1e2,     epsilon_r=1, mu_r=1, density=2267, baseline_T=293, reaction_id=0})
    materials_registry.add("Vac",  {name="Vacuum", flags=0,                          rho=1e20,    epsilon_r=1, mu_r=1, density=1,    baseline_T=293, reaction_id=0})

    -- Positions
    local P_SRC = {x=0, y=0, z=0}
    local P_MID = {x=1, y=0, z=0}
    local P_GND = {x=2, y=0, z=0}

    -- Add voxels
    set_voxel(P_SRC, {flags=materials_flags.CONDUCTOR, material_id="Cu", port_id=1, temperature=293})
    set_voxel(P_MID, {flags=materials_flags.CONDUCTOR, material_id="C",  port_id=2, temperature=293})
    set_voxel(P_GND, {flags=materials_flags.CONDUCTOR, material_id="Cu", port_id=3, temperature=293})

    -- Add POWER ports
    local pos_hash_src = util.hash(P_SRC)
    local pos_hash_mid = util.hash(P_MID)
    local pos_hash_gnd = util.hash(P_GND)
    ports_registry.add{pos_hash=pos_hash_src, face=0, class=types.POWER, state={current_A=0, voltage=5.0}} -- Source: ideal 5V
    ports_registry.add{pos_hash=pos_hash_mid, face=0, class=types.POWER, state={current_A=0, voltage=0.0}} -- Node B: to measure
    ports_registry.add{pos_hash=pos_hash_gnd, face=0, class=types.POWER, state={current_A=0, voltage=0.0}} -- GND

    -- Add ELECTRIC bonds: SRC <-> MID (R), MID <-> GND (C)
    bonds_registry.insert(pos_hash_src, 0, pos_hash_mid, 0, {type=bonds_types.ELECTRIC, R=100.0})   -- 100 ohm
    bonds_registry.insert(pos_hash_mid, 0, pos_hash_gnd, 0, {type=bonds_types.ELECTRIC, C=1e-3})    -- 1 mF

    -- Build island
    local island = {
      voxels = {[pos_hash_src]=true, [pos_hash_mid]=true, [pos_hash_gnd]=true},
      bonds  = {},
      ports  = {1,2,3},
    }

    -- Simulate for 0.1 s in 2 ms steps
    local dt = 0.002
    local steps = math.floor(0.1 / dt)
    for i=1,steps do
      electrical.step(island, dt)
    end

    -- Now check: voltage on MID node should be V=V0*(1-exp(-t/RC))
    local RC = 100 * 1e-3
    local t = steps*dt
    local expected = 5.0 * (1 - math.exp(-t/RC))
    local port2 = ports_registry.lookup(2)
    assert.is_true(math.abs(port2.state.voltage - expected) < 0.05)
  end)

  it("Mechanical: 2 shafts with 4:1 ratio propagate rpm", function()
    -- Material
    materials_registry.add("Steel", {name="Steel", flags=materials_flags.STRUCTURAL, rho=1, epsilon_r=1, mu_r=1, density=7850, baseline_T=293, reaction_id=0})
    -- Positions
    local P_A = {x=0, y=0, z=0}
    local P_B = {x=1, y=0, z=0}
    -- Add voxels
    set_voxel(P_A, {flags=materials_flags.STRUCTURAL, material_id="Steel", port_id=1, temperature=293})
    set_voxel(P_B, {flags=materials_flags.STRUCTURAL, material_id="Steel", port_id=2, temperature=293})
    -- Add ACTUATOR port to A
    local pos_hash_A = util.hash(P_A)
    local pos_hash_B = util.hash(P_B)
    ports_registry.add{pos_hash=pos_hash_A, face=0, class=types.ACTUATOR, state={command=100.0, omega=0}}
    ports_registry.add{pos_hash=pos_hash_B, face=0, class=types.ACTUATOR, state={command=0.0, omega=0}}
    -- Add SHAFT bond with ratio
    bonds_registry.insert(pos_hash_A, 0, pos_hash_B, 0, {type=bonds_types.SHAFT, ratio=4.0, omega_rpm=0, torque_Nm=0})
    -- Build island
    local island = {
      voxels = {[pos_hash_A]=true, [pos_hash_B]=true},
      bonds  = {},
      ports  = {1,2},
    }
    -- Run solver
    mechanical.step(island, 0.05)
    local port2 = ports_registry.lookup(2)
    assert.is_true(math.abs(port2.state.omega - 25.0) < 0.1)
  end)

  it("Thermal: 3-voxel conduction chain reaches steady state", function()
    -- Material
    materials_registry.add("Cu", {name="Copper", flags=materials_flags.CONDUCTOR, rho=1, epsilon_r=1, mu_r=1, density=8960, baseline_T=293, reaction_id=0})
    -- Positions
    local P_A = {x=0, y=0, z=0}
    local P_B = {x=1, y=0, z=0}
    local P_C = {x=2, y=0, z=0}
    -- Set voxels
    set_voxel(P_A, {flags=materials_flags.CONDUCTOR, material_id="Cu", port_id=1, temperature=373}) -- Hot end (100C)
    set_voxel(P_B, {flags=materials_flags.CONDUCTOR, material_id="Cu", port_id=2, temperature=293}) -- Middle (20C)
    set_voxel(P_C, {flags=materials_flags.CONDUCTOR, material_id="Cu", port_id=3, temperature=293}) -- Cold end (20C)
    -- Bonds (thermal)
    local pos_hash_A = util.hash(P_A)
    local pos_hash_B = util.hash(P_B)
    local pos_hash_C = util.hash(P_C)
    bonds_registry.insert(pos_hash_A, 0, pos_hash_B, 0, {type=bonds_types.THERMAL, k=400}) -- W/mK, copper
    bonds_registry.insert(pos_hash_B, 0, pos_hash_C, 0, {type=bonds_types.THERMAL, k=400})
    -- Build island
    local island = {
      voxels = {[pos_hash_A]=true, [pos_hash_B]=true, [pos_hash_C]=true},
      bonds  = {},
      ports  = {1,2,3},
    }
    -- Run for enough time to reach near steady state (say, 10s in 10 ms steps)
    local dt = 0.01
    for i=1,1000 do
      thermal.step(island, dt)
    end
    -- In steady state, T_B should be close to (373+293)/2 = 333K
    local vb = get_voxel(P_B)
    assert.is_true(math.abs(vb.temperature - 333) < 2)
  end)

  it("Chemistry: dummy reaction flips flag after required ticks", function()
    -- Material: REACTIVE at first, CONDUCTOR after
    local F_REACTIVE = materials_flags.REACTIVE
    local F_CONDUCTOR = materials_flags.CONDUCTOR
    materials_registry.add("Dummy", {name="Dummy", flags=F_REACTIVE, rho=1, epsilon_r=1, mu_r=1, density=1, baseline_T=300, reaction_id=1})
    -- Register reaction: needs REACTIVE, min_temp=400, duration=0.1s, becomes CONDUCTOR
    materials_reactions[1] = {
      id = 1,
      react_flags = F_REACTIVE,
      product_flags = F_CONDUCTOR,
      min_temp = 400,
      duration = 0.1,
      enthalpy = 0
    }
    -- Voxel at (0,0,0)
    local pos = {x=0, y=0, z=0}
    set_voxel(pos, {flags=F_REACTIVE, material_id="Dummy", port_id=1, temperature=410, reaction_ticks=0})
    local pos_hash = util.hash(pos)
    -- Build island
    local island = {voxels = {[pos_hash]=true}, bonds={}, ports={1}}
    -- Simulate for 0.2s in 10 ms steps
    local dt = 0.01
    for i=1,20 do
      chemistry.step(island, dt)
    end
    -- Should have flipped to CONDUCTOR (flags = F_CONDUCTOR)
    local v = get_voxel(pos)
    assert.is_true(v.flags == F_CONDUCTOR)
  end)
end)

