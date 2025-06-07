dofile(minetest.get_modpath("moon") .. "/materials/flags.lua")
dofile(minetest.get_modpath("moon") .. "/materials/flags.lua")

-- Reactions table:
-- Each entry:
--   id            = unique integer id
--   react_flags   = flag bits to match (bitwise AND)
--   product_flags = flag bits after reaction
--   min_temp      = minimum temperature in °C to trigger
--   duration      = seconds above min_temp required
--   enthalpy      = J per voxel (negative = exothermic, positive = endothermic)

local reactions = {
  -- Example: Sintering of powder to solid metal
  {
    id = 1,
    react_flags   = MATERIAL.FLUID or MATERIAL.REACTIVE,
    product_flags = MATERIAL.CONDUCTOR or MATERIAL.STRUCTURAL,
    min_temp      = 900,
    duration      = 1.5,
    enthalpy      = -250000,
  },
  -- Example: Annealing of conductor, loses REACTIVE
  {
    id = 2,
    react_flags   = MATERIAL.CONDUCTOR or MATERIAL.REACTIVE,
    product_flags = MATERIAL.CONDUCTOR or MATERIAL.STRUCTURAL,
    min_temp      = 650,
    duration      = 3.0,
    enthalpy      = -100000,
  },
  -- Example: Insulator glass formation
  {
    id = 3,
    react_flags   = MATERIAL.FLUID or MATERIAL.REACTIVE or MATERIAL.INSULATOR,
    product_flags = MATERIAL.INSULATOR or MATERIAL.STRUCTURAL,
    min_temp      = 1200,
    duration      = 2.0,
    enthalpy      = -320000,
  },
  -- Example: Fluid evaporation (e.g., coolant boiling away)
  {
    id = 4,
    react_flags   = MATERIAL.FLUID or MATERIAL.REACTIVE or MATERIAL.CONDUCTOR,
    product_flags = 0, -- becomes inert vapor (flags cleared)
    min_temp      = 1600,
    duration      = 0.5,
    enthalpy      = 400000,
  },
  -- Example: Ferromagnetic ordering lost (Curie point)
  {
    id = 5,
    react_flags   = MATERIAL.FERROMAG,
    product_flags = MATERIAL.STRUCTURAL,
    min_temp      = 770,
    duration      = 2.0,
    enthalpy      = 50000,
  },
  -- Example: Hypothetical reaction for test coverage
  {
    id = 99,
    react_flags   = MATERIAL.REACTIVE,
    product_flags = MATERIAL.INSULATOR,
    min_temp      = 100,
    duration      = 0.1,
    enthalpy      = 0,
  },
}

return {
  reactions = reactions
}

