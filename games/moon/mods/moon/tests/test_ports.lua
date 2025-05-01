-- tests/test_ports.lua
-- Tests port read/write semantics, latch clearing, and callback execution

-- dofile(minetest.get_modpath("moon") .. "/busted/runner.lua")
local types = dofile(minetest.get_modpath("moon").."/ports/types.lua")
local ports_registry = dofile(minetest.get_modpath("moon").."/ports/registry.lua")
local ports_api = dofile(minetest.get_modpath("moon").."/ports/api.lua")
local util = dofile(minetest.get_modpath("moon").."/util.lua")

describe("ports subsystem", function()
  before_each(function()
    -- Reset registry before each test
    ports_registry._reset_for_test = function()
      ports_registry.table = {}
      ports_registry.next_id = 1
      ports_registry._voxel_index = {}
    end
    ports_registry._reset_for_test()
    if ports_api._reset_callbacks then
      ports_api._reset_callbacks()
    end
  end)

  it("registers a new port and retrieves it by id", function()
    local pos_hash = 123456
    local face = 1
    local class = types.POWER
    local state = { current_A = 0.0 }
    local id = ports_registry.add(pos_hash, face, class, state)
    assert.is_number(id)
    local rec = ports_registry.lookup(id)
    assert.is_table(rec)
    assert.equals(pos_hash, rec.pos_hash)
    assert.equals(face, rec.face)
    assert.equals(class, rec.class)
    assert.is_table(rec.state)
    assert.equals(0.0, rec.state.current_A)
  end)

  it("finds all ports for a given voxel", function()
    local pos_hash = 101010
    local id1 = ports_registry.add(pos_hash, 0, types.SENSOR, { value = 1.0 })
    local id2 = ports_registry.add(pos_hash, 2, types.ACTUATOR, { command = 0.5 })
    -- print("id1")
    -- print(id1)
    -- print("id2")
    -- print(id2)
    local ids = {}
    local iterator = ports_registry.ports_for_voxel(pos_hash)
    local id = iterator() 
    -- print()

    while id do
      -- print("id")
      -- print(id)
      local rec = ports_registry.lookup(id)
      -- print("rec and rec.id")
      -- print(rec)
      -- print(rec.id)
      table.insert(ids, rec.id)
      id = iterator()
    end
    table.sort(ids)
    -- print()
    -- print("ids")
    -- print(ids)
    -- print("math.min(id1, id2)")
    -- print(math.min(id1, id2))
    -- print("math.max(id1, id2)")
    -- print(math.max(id1, id2))
    -- rec.id is nil, so ids is being set to nil...
    assert.are.same({math.min(id1, id2), math.max(id1, id2)}, ids)
  end)

  it("writes and reads port latches correctly", function()
    local pos_hash = 4242
    local id = ports_registry.add(pos_hash, 3, types.POWER, { current_A = 0.0 })
    ports_api.write(id, "current_A", 5.0)
    local val = ports_api.read(id, "current_A")
    assert.equals(5.0, val)
  end)

  it("clears latch to zero and persists", function()
    local pos_hash = 333
    local id = ports_registry.add(pos_hash, 4, types.POWER, { current_A = 12.5 })
    ports_api.write(id, "current_A", 0.0)
    local val = ports_api.read(id, "current_A")
    assert.equals(0.0, val)
  end)

  it("invokes callbacks on latch change", function()
    local pos_hash = 8888
    local id = ports_registry.add(pos_hash, 0, types.POWER, { current_A = 0.0 })
    local called = false
    local cb_val = nil
    ports_api.on_change(id, function(newval)
      called = true
      cb_val = newval
    end)
    ports_api.write(id, "current_A", 6.66)
    assert.is_true(called)
    assert.is_table(cb_val)
    assert.equals(6.66, cb_val.current_A)
  end)

  it("does not call callback if value is unchanged", function()
    local pos_hash = 9001
    local id = ports_registry.add(pos_hash, 1, types.POWER, { current_A = 1.5 })
    local count = 0
    ports_api.on_change(id, function()
      count = count + 1
    end)
    ports_api.write(id, "current_A", 1.5) -- No change
    assert.equals(0, count)
    ports_api.write(id, "current_A", 2.0)
    assert.equals(1, count)
  end)

  it("handles multiple callbacks per port", function()
    local pos_hash = 10001
    local id = ports_registry.add(pos_hash, 5, types.SENSOR, { value = 0.0 })
    local c1, c2 = 0, 0
    ports_api.on_change(id, function() c1 = c1 + 1 end)
    ports_api.on_change(id, function() c2 = c2 + 1 end)
    ports_api.write(id, "value", 0.3)
    assert.equals(1, c1)
    assert.equals(1, c2)
  end)

  it("removes a port and ensures it no longer exists", function()
    local pos_hash = 1357
    local id = ports_registry.add(pos_hash, 2, types.ACTUATOR, { command = 0.0 })
    assert.is_table(ports_registry.lookup(id))
    ports_registry.remove(id)
    assert.is_nil(ports_registry.lookup(id))
    -- Also check it's not found in ports_for_voxel
    local found = false
    local iterator = ports_registry.ports_for_voxel(pos_hash)
    local port_id = iterator()
    while port_id do
      if port_id == id then found = true end
      port_id = iterator()
    end
    assert.is_false(found)
  end)
end)

