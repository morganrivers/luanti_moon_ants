-- ports/types.lua
-- Enumerates port classes (POWER, SENSOR, ACTUATOR, MATERIAL_IO, MINE_TOOL, RF_PORT, PHOTO_PORT, THERMO_PORT)
local types = {
  POWER = 1,
  SENSOR = 2,
  ACTUATOR = 3,
  MATERIAL_IO = 4,
  MINE_TOOL = 5,
  RF_PORT = 6,
  PHOTO_PORT = 7,
  THERMO_PORT = 8,
}

-- Port class descriptors specifying per-port state fields
types.descriptors = {
  [types.POWER] = {
    name = "POWER",
    latch_fields = { "current_A" }, -- signed float, electrical/thermal solver
    solvers = { "electrical", "thermal" }
  },
  [types.SENSOR] = {
    name = "SENSOR",
    latch_fields = { "value" }, -- float 0..1, logic solver
    solvers = { "logic" }
  },
  [types.ACTUATOR] = {
    name = "ACTUATOR",
    latch_fields = { "command" }, -- float, mechanical/thermal solver
    solvers = { "mechanical", "thermal" }
  },
  [types.MATERIAL_IO] = {
    name = "MATERIAL_IO",
    latch_fields = { "queue" }, -- array of item stacks, material-flow solver
    solvers = { "material_flow" }
  },
  [types.MINE_TOOL] = {
    name = "MINE_TOOL",
    latch_fields = { "hardness_budget" }, -- float, mining solver
    solvers = { "mining" }
  },
  [types.RF_PORT] = {
    name = "RF_PORT",
    latch_fields = { "packet_buf" }, -- array of packets, rf solver
    solvers = { "rf" }
  },
  [types.PHOTO_PORT] = {
    name = "PHOTO_PORT",
    latch_fields = { "illum" }, -- float, electrical solver
    solvers = { "electrical" }
  },
  [types.THERMO_PORT] = {
    name = "THERMO_PORT",
    latch_fields = { "sideA_K", "sideB_K" }, -- float temps, electrical solver
    solvers = { "electrical" }
  },
}

return types
