-- tests/test_bonds.lua
local busted = require("busted")
local util = dofile(minetest.get_modpath("moon").."/util.lua")
local bond_types = dofile(minetest.get_modpath("moon").."/bonds/types.lua")
local bond_registry = dofile(minetest.get_modpath("moon").."/bonds/registry.lua")
local bond_api = dofile(minetest.get_modpath("moon").."/bonds/api.lua")

describe("Bond API", function()

  local posA = {x=0, y=0, z=0}
  local posB = {x=1, y=0, z=0}
  local posC = {x=0, y=1, z=0}
  local faceA = 1 -- +X
  local faceB = 0 -- -X
  local faceC = 3 -- +Y
  local faceD = 2 -- -Y

  before_each(function()
    -- Clear the registry before each test
    for k in pairs(bond_registry._bonds or {}) do
      bond_registry._bonds[k] = nil
    end
  end)

  it("creates a RIGID bond and verifies symmetry", function()
    assert.is_nil(bond_api.get(posA, faceA))
    local ok, rec = bond_api.create(posA, faceA, posB, faceB, bond_types.RIGID)
    assert.is_true(ok)
    assert.are.equal(rec.type, bond_types.RIGID)

    -- Should be retrievable from either voxel-face
    local recA = bond_api.get(posA, faceA)
    local recB = bond_api.get(posB, faceB)
    assert.is_not_nil(recA)
    assert.is_not_nil(recB)
    assert.are.equal(recA, recB)
  end)

  it("refuses to create duplicate bonds", function()
    local ok1 = bond_api.create(posA, faceA, posB, faceB, bond_types.RIGID)
    assert.is_true(ok1)
    local ok2, err2 = bond_api.create(posA, faceA, posB, faceB, bond_types.RIGID)
    assert.is_false(ok2)
    assert.is_truthy(err2)
  end)

  it("verifies face-opposite and adjacency checks", function()
    -- Not opposite faces
    local ok, err = bond_api.create(posA, faceA, posB, faceC, bond_types.RIGID)
    assert.is_false(ok)
    assert.matches("opposite", err)

    -- Not adjacent
    local ok2, err2 = bond_api.create(posA, faceA, posC, faceB, bond_types.RIGID)
    assert.is_false(ok2)
    assert.matches("adjacent", err2)
  end)

  it("creates HINGE bond with state and updates it", function()
    local state = {theta_deg = 42, torque_Nm=0}
    local ok, rec = bond_api.create(posA, faceA, posB, faceB, bond_types.HINGE, state)
    assert.is_true(ok)
    assert.are.equal(rec.state.theta_deg, 42)
    assert.are.equal(rec.type, bond_types.HINGE)

    bond_api.set_state(rec, "theta_deg", 56)
    assert.are.equal(rec.state.theta_deg, 56)
  end)

  it("creates SHAFT and ELECTRIC bonds and iterates", function()
    bond_api.create(posA, faceA, posB, faceB, bond_types.SHAFT, {omega_rpm=100, torque_Nm=2})
    bond_api.create(posA, faceC, posC, faceD, bond_types.ELECTRIC, {node_id=3})

    local bondsA = {}
    for _,rec in bond_registry.pairs_for_voxel(util.hash(posA)) do
      table.insert(bondsA, rec)
    end
    assert.are.equal(2, #bondsA)
    local found_shaft, found_elec = false, false
    for _,rec in ipairs(bondsA) do
      if rec.type == bond_types.SHAFT then found_shaft = true end
      if rec.type == bond_types.ELECTRIC then found_elec = true end
    end
    assert.is_true(found_shaft)
    assert.is_true(found_elec)
  end)

  it("removes bonds both directions", function()
    bond_api.create(posA, faceA, posB, faceB, bond_types.RIGID)
    assert.is_not_nil(bond_api.get(posA, faceA))
    bond_api.break_bond(posA, faceA)
    assert.is_nil(bond_api.get(posA, faceA))
    assert.is_nil(bond_api.get(posB, faceB))
  end)

  it("does not break unrelated bonds", function()
    bond_api.create(posA, faceA, posB, faceB, bond_types.RIGID)
    bond_api.create(posA, faceC, posC, faceD, bond_types.HINGE)
    bond_api.break_bond(posA, faceA)
    assert.is_nil(bond_api.get(posA, faceA))
    assert.is_not_nil(bond_api.get(posA, faceC))
  end)

  it("allows all canonical bond types", function()
    local types = {
      {bond_types.RIGID, {}},
      {bond_types.HINGE, {theta_deg=0, torque_Nm=0}},
      {bond_types.SLIDER, {offset_mm=0, force_N=0}},
      {bond_types.SHAFT, {omega_rpm=0, torque_Nm=0}},
      {bond_types.ELECTRIC, {node_id=123}},
      {bond_types.THERMAL, {k=0.2}},
    }
    for i, t in ipairs(types) do
      local ok, rec = bond_api.create(
        {x=i, y=0, z=0}, 1,
        {x=i+1, y=0, z=0}, 0,
        t[1], t[2]
      )
      assert.is_true(ok)
      assert.are.equal(rec.type, t[1])
    end
  end)

end)