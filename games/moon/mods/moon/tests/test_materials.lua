-- tests/test_materials.lua
-- Unit tests for material flag registration, density look-ups, reaction triggers

dofile(minetest.get_modpath("moon") .. "/busted.lua")
local flags = dofile("materials/flags.lua")
local registry = dofile("materials/registry.lua")
local reactions = dofile("materials/reactions.lua")

describe("materials.flags", function()
  it("defines all base role flags", function()
    assert.is_number(flags.CONDUCTOR)
    assert.is_number(flags.INSULATOR)
    assert.is_number(flags.FERROMAG)
    assert.is_number(flags.STRUCTURAL)
    assert.is_number(flags.FLUID)
    assert.is_number(flags.REACTIVE)
    assert.is_number(flags.METAL)
    assert.is_false(((flags.METAL and flags.CONDUCTOR) == 0))
    assert.is_false(((flags.METAL and flags.STRUCTURAL) == 0))
  end)
end)

describe("materials.registry", function()
  before_each(function()
    -- Wipe registry before each test to avoid cross-test contamination
    for k in pairs(registry._store or {}) do
      registry._store[k] = nil
    end
  end)

  it("registers and retrieves a material", function()
    registry.add("Fe", {
      name = "Iron",
      flags = flags.METAL,
      ["rho"] = 1e-7,
      ["epsilon_r"] = 1,
      ["mu_r"] = 5000,
      density = 7850,
      baseline_T = 290,
      reaction_id = 0,
    })
    local mat = registry.get("Fe")
    assert.is_table(mat)
    assert.equals("Iron", mat.name)
    assert.equals(flags.METAL, mat.flags)
    assert.is_number(mat.density)
    assert.equals(7850, mat.density)
  end)

  it("finds materials by flag", function()
    registry.add("Fe", {
      name = "Iron", flags = flags.METAL, ["rho"]=1e-7, ["epsilon_r"]=1, ["mu_r"]=5000, density=7850, baseline_T=290, reaction_id=0
    })
    registry.add("Al2O3", {
      name = "Alumina", flags = bit.bor(flags.INSULATOR, flags.STRUCTURAL), ["rho"]=0, ["epsilon_r"]=9, ["mu_r"]=1, density=3970, baseline_T=290, reaction_id=0
    })
    local found = registry.find_by_flag(flags.STRUCTURAL)
    assert.is_table(found)
    local keys = {}
    for _,mat in ipairs(found) do keys[mat.name] = true end
    assert.is_true(keys["Iron"])
    assert.is_true(keys["Alumina"])
  end)

  it("returns nil for unknown material id", function()
    assert.is_nil(registry.get("nonexistent"))
  end)
end)

describe("materials.reactions", function()
  it("contains valid reaction entries", function()
    assert.is_table(reactions)
    for _,rxn in ipairs(reactions) do
      assert.is_number(rxn.id)
      assert.is_number(rxn.react_flags)
      assert.is_number(rxn.product_flags)
      assert.is_number(rxn.min_temp)
      assert.is_number(rxn.duration)
      assert.is_number(rxn.enthalpy)
    end
  end)

  it("triggers a reaction when flags and temperature match", function()
    -- Mock a reaction table for deterministic testing
    local rx = {
      id = 1,
      react_flags = flags.REACTIVE,
      product_flags = bit.bor(flags.CONDUCTOR, flags.STRUCTURAL),
      min_temp = 500,
      duration = 2.0,
      enthalpy = -100000,
    }
    local function check_reaction(voxel, temp, time)
      if (not ((voxel.flags and rx.react_flags) == 0)) and temp >= rx.min_temp and time >= rx.duration then
        voxel.flags = rx.product_flags
        return true
      end
      return false
    end
    local v = {flags = flags.REACTIVE}
    local fired = check_reaction(v, 600, 2.0)
    assert.is_true(fired)
    assert.equals(rx.product_flags, v.flags)
  end)
end)

