-- bonds/types.lua
-- Enumerates bond kinds (RIGID,HINGE,SLIDER,SHAFT,ELECTRIC,THERMAL) and their per-bond state fields

local types = {
  -- Enum for bond kinds
  RIGID    = 1,
  HINGE    = 2,
  SLIDER   = 3,
  SHAFT    = 4,
  ELECTRIC = 5,
  THERMAL  = 6,

  -- Bond state descriptors: fields required for each bond kind
  fields = {
    [1] = {}, -- RIGID: no extra state
    [2] = { "theta_deg", "torque_Nm" }, -- HINGE
    [3] = { "offset_mm", "force_N" },   -- SLIDER
    [4] = { "omega_rpm", "torque_Nm" }, -- SHAFT
    [5] = { "node_id" },                -- ELECTRIC
    [6] = { "k" },                      -- THERMAL
  },

  -- Default state values for each bond type (for initialization)
  defaults = {
    [1] = {}, -- RIGID
    [2] = { theta_deg = 0, torque_Nm = 0 },           -- HINGE
    [3] = { offset_mm = 0, force_N = 0 },             -- SLIDER
    [4] = { omega_rpm = 0, torque_Nm = 0 },           -- SHAFT
    [5] = { node_id = 0 },                            -- ELECTRIC
    [6] = { k = 0 },                                  -- THERMAL
  },

  -- Bond kind names for debugging
  name = {
    [1] = "RIGID",
    [2] = "HINGE",
    [3] = "SLIDER",
    [4] = "SHAFT",
    [5] = "ELECTRIC",
    [6] = "THERMAL",
  }
}

return types